module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Require the netatmo library
  netatmo = require 'netatmo'

  # Plugin class
  class NetatmoPlugin extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      env.logger.info("Starting pimatic-netatmo plugin")

      # get the device config schemas
      deviceConfigDef = require("./device-config-schema")

      #create the auth data
      @auth = 
        "client_id": @config.client_id
        "client_secret": @config.client_secret
        "username": @config.username
        "password": @config.password
      
      #globally make netatmo api available
      @netatmo_api = new netatmo @auth 

      #function for reconnection on connection loss
      @reconnect = () =>
        @netatmo_api.authenticate @auth
      
      #error handling for netatmo api
      @netatmo_api.on "error", (error) =>
        if error.message.match /Authenticate.*No response/
          #looks like we can't connect to the API
          env.logger.error "Can't connect to netatmo API, retry in 30s"
          #reconnect after some time
          setTimeout @reconnect, 30000

        else if error.message.match /Authenticate.*invalid_grant/
          #looks like something is wrong with the credentials
          env.logger.error "Credentials incorrect, please check client_id, client_secret, username and password"

        else
          env.logger.error "Netatmo API error: #{error.message}"

      @netatmo_api.on "warning", (error) =>
        if error.message.match /getMeasure.*No response/
          env.logger.warn "Could not retreive measurement from API, check network connection"

        else if error.message.match /Status code403/
          #looks like our session got killed, reauthenticate
          env.logger.error "Session seems to be not vailid anymore, trying to reauthenticate"
          @netatmo_api.authenticate @auth

        else
          env.logger.warn "Netatmo API warning: #{error.message}"

      @netatmo_api.on "authenticated", () =>
        env.logger.info "Netatmo API sucessfully authenticated"




      #promisify the api
      Promise.promisifyAll @netatmo_api

      #try to get the device list and print it to the log for easy setup of the devices
      @netatmo_api.getStationsDataAsync()
      .then (devices) =>
        #env.logger.info devices
        #env.logger.info devices[0].modules
        for device in devices
          env.logger.info "Station Name: #{device.station_name}     Module Name: #{device.module_name}     Device ID: #{device._id}"
          for module in device.modules
            env.logger.info "Module Name: #{module.module_name}     Module ID: #{module._id}"
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true        

      #add the devices
      @framework.deviceManager.registerDeviceClass("NetatmoBase", {
        configDef: deviceConfigDef.NetatmoBase,
        createCallback: (config, lastState) =>
          return new NetatmoBase(config, @, lastState)
      })
      @framework.deviceManager.registerDeviceClass("NetatmoOutdoorModule", {
        configDef: deviceConfigDef.NetatmoOutdoorModule,
        createCallback: (config, lastState) =>
          return new NetatmoOutdoorModule(config, @, lastState)
      })
      @framework.deviceManager.registerDeviceClass("NetatmoIndoorModule", {
        configDef: deviceConfigDef.NetatmoIndoorModule,
        createCallback: (config, lastState) =>
          return new NetatmoIndoorModule(config, @, lastState)
      })
      @framework.deviceManager.registerDeviceClass("NetatmoWindGauge", {
        configDef: deviceConfigDef.NetatmoWindGauge,
        createCallback: (config, lastState) =>
          return new NetatmoWindGauge(config, @, lastState)
      })
      @framework.deviceManager.registerDeviceClass("NetatmoRainSensor", {
        configDef: deviceConfigDef.NetatmoRainSensor,
        createCallback: (config, lastState) =>
          return new NetatmoRainSensor(config, @, lastState)
      })


  #Netatmo basic device class
  class NetatmoDevice extends env.devices.Device

    #Basic device constuctor
    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @device_id = @config.device_id
      @interval = 1000 * @config.interval


      updateValue = =>
        if @config.interval > 0
          @getDeviceData().finally( =>
            env.logger.debug "Scheduling next update for #{@name} with interval #{@interval}ms"
            @timeoutId = setTimeout(updateValue, @interval)
          )
      
      super()
      updateValue()

    destroy: () ->
      clearTimeout(@timeoutId) if @timeoutId?
      @_currentRequest.cancel() if @_currentRequest?
      super()

    _toFixed: (value, nDecimalDigits) ->
      if _.isNumber(value)
        return Number value.toFixed(nDecimalDigits)
      else
        return Number value

    _setAttribute: (attributeName, value) ->
      unless @[attributeName] is value
        @[attributeName] = value
        @emit attributeName, value


  class NetatmoModuleDevice extends NetatmoDevice

    #Module Device constructor
    constructor: (@config, @plugin, lastState) ->
      #for modules we additionally need the module id in the constructor
      @module_id = @config.module_id
      #rest is the same as base class
      super(@config, @plugin, lastState)


  # Device class Netatmo Base Station
  class NetatmoBase extends NetatmoDevice
    # Attributes
    attributes:
      temperature:
        description: "Temperature measured at Netatmo Base"
        type: "number"
        unit: '°C'
        acronym: 'Temperature'
      co2:
        description: "CO2 measured at Netatmo Base"
        type: "number"
        unit: 'ppm'
        acronym: 'CO2'
      humidity:
        description: "Humidity measured at Netatmo Base"
        type: "number"
        unit: '%'
        acronym: 'Humidity'
      pressure:
        description: "Pressure measured at Netatmo Base"
        type: "number"
        unit: 'mbar'
        acronym: 'Pressure'
      noise:
        description: "Noise measured at Netatmo Base"
        type: "number"
        unit: "db"
        acronym: "Noise"

    temperature = null
    co2 = null
    humidity = null
    pressure = null
    noise = null

    getDeviceData: () ->
     options =
        device_id: @device_id,
        scale: 'max',
        type: ['Temperature', 'CO2', 'Humidity', 'Pressure', 'Noise'],
        date_end: "last"
       
      @_currentRequest = @plugin.netatmo_api.getMeasureAsync options
      .then (measure) =>
        env.logger.debug measure[0].value[0]
        if measure
          temperature = measure[0].value[0][0]
          @_setAttribute "temperature", temperature
          
          co2 = measure[0].value[0][1]
          @_setAttribute "co2", co2

          humidity = measure[0].value[0][2]
          @_setAttribute "humidity", humidity

          pressure = measure[0].value[0][3]
          @_setAttribute "pressure", pressure

          noise = measure[0].value[0][4]
          @_setAttribute "noise", noise

          return Promise.resolve()
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true

    getTemperature: -> @_currentRequest.then(=> @temperature )
    getCo2: -> @_currentRequest.then(=> @co2 )
    getHumidity: -> @_currentRequest.then(=> @humidity )
    getPressure: -> @_currentRequest.then(=> @pressure )
    getNoise: -> @_currentRequest.then(=> @noise )


  # Device class Netatmo Outdoor Module
  class NetatmoOutdoorModule extends NetatmoModuleDevice
    # Attributes
    attributes:
      temperature:
        description: "Temperature measured at Netatmo Outdoor Module"
        type: "number"
        unit: '°C'
        acronym: 'Temperature'
      humidity:
        description: "Humidity measured at Netatmo Outdoor Module"
        type: "number"
        unit: '%'
        acronym: 'Humidity'

    temperature = null
    humidity = null

    getDeviceData: () ->
     options =
        device_id: @device_id,
        module_id: @module_id,
        scale: 'max',
        type: ['Temperature', 'Humidity'],
        date_end: "last"
        
      @_currentRequest = @plugin.netatmo_api.getMeasureAsync options
      .then (measure) =>
        env.logger.debug measure[0].value[0]
        if measure
          temperature = measure[0].value[0][0]
          @_setAttribute "temperature", temperature

          humidity = measure[0].value[0][1]
          @_setAttribute "humidity", humidity

          return Promise.resolve()
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true

    getTemperature: -> @_currentRequest.then(=> @temperature )
    getHumidity: -> @_currentRequest.then(=> @humidity )


  # Device class Netatmo Indoor Module
  class NetatmoIndoorModule extends NetatmoModuleDevice
    # Attributes
    attributes:
      temperature:
        description: "Temperature measured at Netatmo Indoor Module"
        type: "number"
        unit: '°C'
        acronym: 'Temperature'
      co2:
        description: "CO2 measured at Netatmo Indoor Module"
        type: "number"
        unit: 'ppm'
        acronym: 'CO2'
      humidity:
        description: "Humidity measured at Netatmo Indoor Module"
        type: "number"
        unit: '%'
        acronym: 'Humidity'

    temperature = null
    co2 = null
    humidity = null

    destroy: () ->
      clearTimeout(@timeoutId) if @timeoutId?
      @_currentRequest.cancel() if @_currentRequest?
      super()

    getDeviceData: () ->
     options =
        device_id: @device_id,
        module_id: @module_id,
        scale: 'max',
        type: ['Temperature', 'CO2', 'Humidity'],
        date_end: "last"
       
      @_currentRequest = @plugin.netatmo_api.getMeasureAsync options
      .then (measure) =>
        env.logger.debug measure[0].value[0]
        if measure
          temperature = measure[0].value[0][0]
          @_setAttribute "temperature", temperature
          
          co2 = measure[0].value[0][1]
          @_setAttribute "co2", co2

          humidity = measure[0].value[0][2]
          @_setAttribute "humidity", humidity

          return Promise.resolve()
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true

    getTemperature: -> @_currentRequest.then(=> @temperature )
    getCo2: -> @_currentRequest.then(=> @co2 )
    getHumidity: -> @_currentRequest.then(=> @humidity )


  # Device class Netatmo Wind Module
  class NetatmoWindGauge extends NetatmoModuleDevice
    # Attributes
    attributes:
      windstrength:
        description: "Wind strength measured at Netatmo Wind Gauge"
        type: "number"
        unit: 'km/h'
        acronym: 'Wind strength'
      winddirection:
        description: "Wind direction measured at Netatmo Wind Gauge"
        type: "number"
        unit: '°'
        acronym: 'Wind dir.'
      gustspeed:
        description: "Gust strength measured at Netatmo Wind Gauge"
        type: "number"
        unit: 'km/h'
        acronym: 'Gust strength'
      gustdirection:
        description: "Gust direction measured at Netatmo Wind Gauge"
        type: "number"
        unit: '°'
        acronym: 'Gust dir.'

    windspeed = null
    winddirection = null
    gustspeed = null
    gustdirection = null

    getDeviceData: () ->
     options =
        device_id: @device_id,
        module_id: @module_id,
        scale: 'max',
        type: ['WindStrength', 'WindAngle', 'GustStrength', 'GustAngle'],
        date_end: "last"
       
      @_currentRequest = @plugin.netatmo_api.getMeasureAsync options
      .then (measure) =>
        env.logger.debug measure[0].value[0]
        if measure
          windspeed = measure[0].value[0][0]
          @_setAttribute "windspeed", windspeed
          
          winddirection = measure[0].value[0][1]
          @_setAttribute "winddirection", winddirection

          gustspeed = measure[0].value[0][2]
          @_setAttribute "gustspeed", gustspeed

          gustdirection = measure[0].value[0][3]
          @_setAttribute "gustdirection", gustdirection

          return Promise.resolve()
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true

    getWindspeed: -> @_currentRequest.then(=> @windspeed )
    getWiddirection: -> @_currentRequest.then(=> @winddirection )
    getGustspeed: -> @_currentRequest.then(=> @gustspeed )
    getGustdirection: -> @_currentRequest.then(=> @gustdirection )


  # Device class Netatmo Wind Module
  class NetatmoRainSensor extends NetatmoModuleDevice
    # Attributes
    attributes:
      rain:
        description: "Wind strength measured at Netatmo Wind Gauge"
        type: "number"
        unit: 'mm'
        acronym: 'Rain'

    rain = null

    getDeviceData: () ->
     options =
        device_id: @device_id,
        module_id: @module_id,
        scale: 'max',
        type: ['Rain'],
        date_end: "last"
      
       
      @_currentRequest = @plugin.netatmo_api.getMeasureAsync options
      .then (measure) =>
        env.logger.debug measure[0].value[0]
        if measure
          rain = measure[0].value[0][0]
          @_setAttribute "rain", rain

          return Promise.resolve()
      .catch (err) =>
        #we do nothing here,this is hadled by the main error handling
        return true


  # ###Finally
  # Create a instance of my plugin
  netatmoPlugin = new NetatmoPlugin
  # and return it to the framework.
  return netatmoPlugin
