### Backbone.Authenticator

Provides OAuth2 client support to Backbone applications.

###

# TODO: Remove dependency on jQuery.deparam, which can be found here until then:
# https://gist.github.com/raw/1025817/bd35871da67be0073fffc37414e3e18e627b0d22/jquery.ba-deparam.js

# Create references to depenencies in the local scope
Backbone = window.Backbone or {}

_ = window._

jQuery = window.jQuery
$ = jQuery

# Creates our Authenticator namespace if it doesn't already exist
Backbone.Authenticate = Backbone.Authenticate or {}

Backbone.Authenticate.defaultRegistry = defaultRegistry =
    popup: true
    responseType: 'code'
    grantType: 'authorization_code'

    paramNames:
      client_id: 'client_id'
      client_secret: 'client_secret'
      redirect_uri: 'redirect_uri'
      scope: 'scope'
      state: 'state'
      response_type: 'response_type'
      grant_type: 'grant_type'
      code: 'code'

Backbone.Authenticate.Authenticator = class Authenticator
  """ Core object which can be used to perform all authentication-related tasks.

  """

  # When we have a token, it will be stored here.
  token: null

  # During the auth process, this is the window where authentication is occuring.
  dialog: null

  requiredOptions: [
    'authenticateURI',
    'redirectURI',
    'clientID',
  ]

  responseHandlerPrefix: 'handle'

  registry: defaultRegistry

  constructor: (options) ->
    _.extend @, Backbone.Events

    options = options or {}
    @parseOptions options

  parseOptions: (options) ->
    _.extend @registry, options

    for name in @requiredOptions

      # If someone creates an inherited class that defines these, we're okay.
      if @registry[name] then continue

      # Throws an error if a required option hasn't been provided.
      @registry[name]? or

        throw new Error "An #{name} option must be provided to your
                         Authenticator."

    if @registry.responseType? and !@[@methodNameForResponseType @registry.responseType]?
        throw new Error "#{@registry.responseType} is not a supported response
                         type for this authenticator."

    if @registry.responseType == 'code'

      if !@registry.authorizeURI?
        throw new Error 'Code-based authentication requires authorizeURI
                         is provided to your authenticator.'

      if !@registry.grantType?
        throw new Error 'The grantType option must be provided when using
                         code-based authentication.'

  authenticateURI: ->
    ### Builds the URL to our initial OAuth endpoint.                      ###

    params = {}

    params[@registry.paramNames.client_id] = @registry.clientID
    params[@registry.paramNames.redirect_uri] = @registry.redirectURI
    params[@registry.paramNames.response_type] = @registry.responseType

    # Add state and scope as necessary
    if @registry.state? then params[@registry.paramNames.state] = @registry.state
    if @registry.scope? then params[@registry.paramNames.scope] = @registry.scope

    paramNames = _.keys params

    # Convert our params object to a list of strings formatted with '='
    paramString = _.map paramNames, (name) ->
      if params[name]? and params[name] != ''
        return name + '=' + params[name]
      else
        return name

    paramString = paramString.join '&'

    @registry.authenticateURI + '?' + paramString

  authorizationData: (code) ->
    ### Builds the URL for our authorization endpoint for getting tickets. ###
    
    params = {}

    params[@registry.paramNames.client_id] = @registry.clientID
    params[@registry.paramNames.grant_type] = @registry.grantType
    params[@registry.paramNames.redirect_uri] = @registry.redirectURI
    params[@registry.paramNames.code] = code

    if @registry.clientSecret?
      params[@registry.paramNames.client_secret] = @registry.clientSecret

    return params

  methodNameForResponseType: (typeName) ->
    ### Receives a response type and converts it into it's handler's method name.

    ###

    formattedTypeName = typeName[0].toUpperCase() + typeName[1..].toLowerCase()

    return @responseHandlerPrefix + formattedTypeName

  begin: =>
    ### Initiates the user authentication process.

    Initiates the user authentication process. Optionally, you can provide any
    registry options that this process should override.

    ###

    authenticateURI = @authenticateURI()

    if @registry.popup is true
      @dialog = window.open authenticateURI

    else
      # TODO: Test whether or not this even works
      window.location = authenticateURI

  processResponse: =>
    ### After authentication, this function finishes the authentication process.

    ###

    parameters = jQuery.deparam window.location.search[1..]

    # Get a reference to our function that handles this type of response
    handlerName = @methodNameForResponseType @registry.responseType
    handler = @[handlerName]

    # Call our handler method providing parameters object
    handler parameters

  handleCode: (parameters) =>
    ### Response handler for "code" response type.

    ####
    
    if !parameters.code?
      throw new Error 'No code parameter was provided by the provider.'

    jQuery.ajax 
      type: 'POST'
      url: @registry.authorizeURI
      data: @authorizationData parameters.code

      success: (response) => @processToken

  handleToken: (parameters) =>
    ### Response handler for "token" response type.

    ###

    if !parameters.token?
      throw new Error 'No token parameter was provided by the OAuth provider.'

    @processToken parameters.token

  processToken: (response) ->
    @token = response.access_token
    @trigger 'token:changed'

