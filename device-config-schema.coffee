module.exports = {
  title: "pimatic-netatmo device config schemas"
  NetatmoBase: {
    title: "Netatmo Base Station"
    description: "Netatmo Base Station which can provide temperature, CO2, humidity, pressure, noise"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      device_id:
        description: "Device ID retrieved from plugin startup output"
        type: "string"
      interval:
        description: "Polling interval for current measurements (>60s recommended)"
        type: "number"
        default: 60
  }
  NetatmoOutdoorModule: {
    title: "Netatmo Outdoor Module"
    description: "Netatmo Outdoor Module which can provide temperature and humidity"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      device_id:
        description: "Base Station Device ID retrieved from plugin startup output"
        type: "string"
      module_id:
        description: "Module ID retrieved from plugin startup output"
        type: "string"
      interval:
        description: "Polling interval for current measurements (>60s recommended)"
        type: "number"
        default: 60
  }
  NetatmoIndoorModule: {
    title: "Netatmo Indoor Module"
    description: "Netatmo Indoor Module which can provide temperature, humidity and CO2"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      device_id:
        description: "Base Station Device ID retrieved from plugin startup output"
        type: "string"
      module_id:
        description: "Module ID retrieved from plugin startup output"
        type: "string"
      interval:
        description: "Polling interval for current measurements (>60s recommended)"
        type: "number"
        default: 60
  }
  NetatmoRainSensor: {
    title: "Netatmo Rain Sensor"
    description: "Netatmo Rain Sensor which can provide rain measurements"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      device_id:
        description: "Base Station Device ID retrieved from plugin startup output"
        type: "string"
      module_id:
        description: "Module ID retrieved from plugin startup output"
        type: "string"
      interval:
        description: "Polling interval for current measurements (>60s recommended)"
        type: "number"
        default: 60
  }
  NetatmoWindGauge: {
    title: "Netatmo Wind Gauge"
    description: "Netatmo Wind Gauge which can provide wind strength and wind angle"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      device_id:
        description: "Base Station Device ID retrieved from plugin startup output"
        type: "string"
      module_id:
        description: "Module ID retrieved from plugin startup output"
        type: "string"
      interval:
        description: "Polling interval for current measurements (>60s recommended)"
        type: "number"
        default: 60
  }
}