# Pimatic Netatmo configuration options
# Declare your config option for your plugin here. 
module.exports = {
  title: "Netatmo Settings"
  type: "object"
  properties:
    client_id:
      description: "Netatmo client id obtained via https://dev.netatmo.com/dev/createapp"
      type: "string"
      default: ""
    client_secret:
      description: "Netatmo client secret obtained via https://dev.netatmo.com/dev/createapp"
      type: "string"
      default: ""
    username:
      description: "Netatmo username"
      type: "string"
      default: ""
    password:
      description: "Netatmo password"
      type: "string"
      default: ""
}