###*
Forms and controls
==================
  
Up.js comes with functionality to submit forms without
leaving the current page. This means you can replace page fragments,
open dialogs with sub-forms, etc. all without losing form state.
  
\#\#\# Incomplete documentation!
  
We need to work on this page:
  
- Explain how to display form errors
- Explain that the server needs to send 2xx or 5xx status codes so
  Up.js can decide whether the form submission was successful
- Explain that the server needs to send an `X-Up-Previous-Redirect-Location` header
  if an successful form submission resulted in a redirect
- Examples
  

  
@class up.form
###
up.form = (->
  
  u = up.util

  ###*
  Submits a form using the Up.js flow:

      up.submit('form.new_user')

  @method up.submit
  @param {Element|jQuery|String} formOrSelector
    A reference or selector for the form to submit.
    If the argument points to an element that is not a form,
    Up.js will search its ancestors for the closest form.
  @param {String} [options.target]
  @param {String} [options.failTarget]
  @param {Boolean|String} [options.history=true]
    Successful form submissions will add a history entry and change the browser's
    location bar if the form either uses the `GET` method or the response redirected
    to another page (this requires the `upjs-rails` gem).
    If want to prevent history changes in any case, set this to `false`.
    If you pass a `String`, it is used as the URL for the browser history.
  @param {String} [options.transition]
  @param {String} [options.failTransition]
  @return {Promise}
    A promise for the AJAX response
  ###
  submit = (formOrSelector, options) ->
    
    $form = $(formOrSelector).closest('form')

    options = u.options(options)
    successSelector = u.option(options.target, $form.attr('up-target'), 'body')
    failureSelector = u.option(options.failTarget, $form.attr('up-fail-target'), -> u.createSelectorFromElement($form))
    historyOption = u.option(options.history, $form.attr('up-history'), true)
    successTransition = u.option(options.transition, $form.attr('up-transition'))
    failureTransition = u.option(options.failTransition, $form.attr('up-fail-transition'))
    
    $form.addClass('up-active')

    request = {
      url: $form.attr('action') || up.browser.url()
      type: $form.attr('method')?.toUpperCase() || 'POST',
      data: $form.serialize(),
      selector: successSelector
    }

    successUrl = (xhr) ->
      url = if historyOption
        if u.isString(historyOption)
          historyOption
        else if redirectLocation = xhr.getResponseHeader('X-Up-Previous-Redirect-Location')
          redirectLocation
        else if request.type == 'GET'
          request.url + '?' + request.data
      u.option(url, false)

    u.ajax(request)
      .always ->
        $form.removeClass('up-active')
      .done (html, textStatus, xhr) ->
        up.flow.implant(successSelector, html,
          history: successUrl(xhr),
          transition: successTransition
        )
      .fail (xhr, textStatus, errorThrown) ->
        html = xhr.responseText
        up.flow.implant(failureSelector, html,
          transition: failureTransition
        )

  ###*
  Observes an input field by periodic polling its value.
  Executes code when the value changes.

      up.observe('input', { change: function(value, $input) {
        up.submit($input)
      } });

  This is useful for observing text fields while the user is typing,
  since browsers will only fire a `change` event once the user
  blurs the text field.

  @method up.observe
  @param {Element|jQuery|String} fieldOrSelector
  @param {Function(value, $field)|String} options.change
    The callback to execute when the field's value changes.
    If given as a function, it must take two arguments (`value`, `$field`).
    If given as a string, it will be evaled as Javascript code in a context where
    (`value`, `$field`) are set.
  @param {Number} [options.frequency=500]
  ###
  observe = (fieldOrSelector, options) ->

    $field = $(fieldOrSelector)
    options = u.options(options, frequency: 500)
    knownValue = null
    timer = null
    callback = null
    if codeOnChange = $field.attr('up-observe')
      callback = (value, $field) ->
        eval(codeOnChange)
    else if options.change
      callback = options.change
    else
      u.error('observe: No change callback given')

    check = ->
      value = $field.val()
      skipCallback = _.isNull(knownValue) # don't run the callback for the check during initialization
      if knownValue != value
        knownValue = value
        callback.apply($field.get(0), [value, $field]) unless skipCallback

    resetTimer = ->
      if timer
        clearTimer()
        startTimer()

    clearTimer = ->
      clearInterval(timer)
      timer = null

    startTimer = ->
      timer = setInterval(check, options.frequency)

    # reset counter after user interaction
    $field.bind "keyup click mousemove", resetTimer # mousemove is for selects

    check()
    startTimer()

    # return destructor
    return clearTimer

  ###*
  Submits the form through AJAX, searches the response for the selector
  given in `up-target` and replaces the selector content in the current page:

      <form method="POST" action="/users" up-target=".main">
        ...
      </form>

  @method form[up-target]
  @ujs
  @param {String} up-target
  @param {String} [up-fail-target]
  @param {String} [up-history]
  @param {String} [up-transition]
  @param {String} [up-fail-transition]
  ###
  up.on 'submit', 'form[up-target]', (event, $form) ->
    event.preventDefault()
    submit($form)

  ###*
  Observes this form control by periodically polling its value.
  Executes the given Javascript if the value changes:

      <form method="GET" action="/search">
        <input type="query" up-observe="up.form.submit(this)">
      </form>

  This is useful for observing text fields while the user is typing,
  since browsers will only fire a `change` event once the user
  blurs the text field.

  @method input[up-observe]
  @ujs
  @param {String} up-observe 
  ###
  up.awaken '[up-observe]', ($field) ->
    return observe($field)

#  up.awaken '[up-autosubmit]', ($field) ->
#    return observe($field, change: ->
#      $form = $field.closest('form')
#      $field.addClass('up-active')
#      up.submit($form).always ->
#        $field.removeClass('up-active')
#    )

  submit: submit
  observe: observe

)()

up.submit = up.form.submit
up.observe = up.form.observe