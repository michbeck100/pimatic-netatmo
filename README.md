Pimatic Netatmo plugin
=======================
For this plugin to work you need to register an application with netatmo.
This only takes a few seconds on the netatmo developer page with your normal netatmo account.

https://dev.netatmo.com/dev/createapp

Just provide a Name and a Description and accept the "terms of use" and click create.
You will be immediately presented with the needed credentials.


Example config.json entries:

  "plugins": [
    {
      "plugin": "netatmo",
      "client_id": "1293484deadbeef1112344de",
      "client_secret": "SoM3f4NcyS3crE7fR0mN3t4Tm0",
      "username": "blah@blub.com",
      "password": "TheMostSecurePasswordInTheWorld42"
    }
  ],

  "devices": [
    {
      "id": "netatmo-test",
      "name": "My Netatmo Base",
      "class": "NetatmoBase",
      "device_id": "XX:XX:XX:XX:XX:XX",
      "interval": 30
    },
    {
      "id": "netatmo-otdoor",
      "name": "My Netatmo Outdoor",
      "class": "NetatmoOutdoorModule",
      "device_id": "XX:XX:XX:XX:XX:XX",
      "module_id": "XX:XX:XX:XX:XX:XX",
      "interval": 30
    }
  ]

  I also added support for NetatmoIndoorModule, NetatmoRainSensor and NetatmoWindGauge
  but as I don't have the hardware this is completely untested. Feel free to donate hardware.