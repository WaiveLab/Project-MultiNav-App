# Project MulitNav App
A vibrotactile wayifinding app that enables blind and low vision (BLV) users to navigate outdoor environments.

## Structure
### json
.json files should be structured as the following:
```
Start
|
Street X
| landmarks near/on the street
Intersection between street X & Y
|
Street Y
| landmarks near/on the street
End
```

For example:
```json
{
    "id": "st",
    "type": "landmark",
    "geometry": { "type": "Point", "coordinates": [700,1800]},
    "properties": { "name": "Deniel and Pamella DeVos Center", "level": 1, "accessible": true}
},



{
    "id": "str0",
    "type": "corridor",
    "geometry": { "type": "LineString", "coordinates": [[700,1800],[700,-200]] },
    "properties": { "name": "Michigan Street North East", "level": 1, "accessible": true}
},
{
    "id": "rmp0",
    "type": "landmark",
    "geometry": { "type": "Point", "coordinates": [700, 1700] },
    "properties": { "name": "Ramp on Michigan Street North East", "level": 1, "accessible": true}
},



{
    "id": "int0",
    "type": "intersection",
    "geometry": { "type": "Point", "coordinates": [700, 1200] },
    "properties": { "name": "Intersection Between Michigan Street North East and Prospect Avenue North East", "level": 1, "accessible": false}
},



{
    "id": "str1",
    "type": "corridor",
    "geometry": { "type": "LineString", "coordinates": [[200, 1200], [700, 1200]] },
    "properties": { "name": "Prospect Avenue North East", "level": 1, "accessible": true }
},



{
    "id": "end",
    "type": "landmark",
    "geometry": { "type": "Point", "coordinates": [400,0]},
    "properties": { "name": "Hampton Inn & Suites", "level": 1, "accessible": true}
}
```
