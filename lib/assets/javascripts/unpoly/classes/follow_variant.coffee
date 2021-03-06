u = up.util
e = up.element

class up.FollowVariant

  constructor: (selector, options) ->
    # @followLink() will wrap @followNow() with event submission and [up-active] feedback
    @followNow = options.follow
    @preloadLink = options.preload
    @selectors = u.splitValues(selector, ',')

  onClick: (event, link) =>
    if up.link.shouldProcessEvent(event, link)
      if e.matches(link, '[up-instant]')
        # If the link was already processed on mousedown, we still need
        # to prevent this later click event's chain.
        up.event.halt(event)
      else
        up.event.consumeAction(event)
        @followLink(link)
    else
      # For tests
      up.link.allowDefault(event)

  onMousedown: (event, link) =>
    if up.link.shouldProcessEvent(event, link)
      up.event.consumeAction(event)
      @followLink(link)

  fullSelector: (additionalClause = '') =>
    parts = []
    @selectors.forEach (variantSelector) ->
      for tagSelector in ['a', '[up-href]']
        parts.push "#{tagSelector}#{variantSelector}#{additionalClause}"
    parts.join(', ')

  registerEvents: ->
    up.on 'click', @fullSelector(), (args...) =>
      u.muteRejection @onClick(args...)
    up.on 'mousedown', @fullSelector('[up-instant]'), (args...) =>
      u.muteRejection @onMousedown(args...)

  followLink: (link, options = {}) =>
    promise = up.event.whenEmitted('up:link:follow', log: 'Following link', target: link)
    promise = promise.then =>
      up.feedback.start(link) unless options.preload
      @followNow(link, options)
    unless options.preload
      # Make sure we always remove .up-active, even if the follow fails or the user
      # does not confirm an [up-confirm] link. However, don't re-assign promise
      # to the result of up.always() since that would change the state of promise.
      u.always promise, -> up.feedback.stop(link)
    promise

  matchesLink: (link) =>
    e.matches(link, @fullSelector())
