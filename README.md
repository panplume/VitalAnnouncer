#VitalAnnouncer

![VitalAnnouncer beartastrophe](/VA.png)

Report important spells for others to see. You can toggle which one will be reported in the option panel (ESC / Interface / Addons / VitalAnnouncer). Two lists of spells are available (adding a new spell requires source editing):

1. Spell you cast but missed (important debuff)
1. Interrupt you made

Additionally the addon reports *spell steal* et *purge*.

![VitalAnnouncer option panel](/VAOptionPanel.png)

#Command line usage (/va or /vitalannouncer)

| Command                      | Description                            |
|------------------------------|----------------------------------------|
| /va say                      | Report in /s                           |
| /va whisper <*player name*>  | Report in /w                           |
| /va channel <*channel name*> | Report in channel already joined       |
| /va active                   | Toggle addon reporting globally        |
| /va interrupt                | Toggle interrupt reporting (if active) |
| /va reset                    | Return all values to defaults          |
| /va                          | Open the option panel to choose spells |

#Command line example:

```
/join UwUwarrior
/va channel UwUwarrior
```
