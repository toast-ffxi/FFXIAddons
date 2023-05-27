# AutoTargetAssist

Addon for Windower 4 for FFXI. Tracks party and enemy actions to create a pseudo enmity list and uses customizeable parameters to pick the next target to attack when your current target dies. Also has features for an on-screen enmity list, and raid assist target.

<img src="https://i.imgur.com/clNPngP.png">

### Commands

| Commands | Function |
| --- | --- |
| //ata on / off | Turns auto targeting on or off. |
| //ata help | Displays command list in chat window. |
| //ata d / distance [number] | Sets the maximum auto targeting distance. |
| //ata hpf / hpfilter <h / high / highest, l / low / lowest, n / none> | Sets hpfilter value. If set to any value other than none will prioritize enemies based on remaining hp. None will auto target based on distance only. |
| //ata pf / pet / petfilter <t / true, f / false> | Sets petfilter value. If true, enemy pets will not be tracked. |
| //ata ps / sim / prefersimilar <t / true, f / false> | Sets prefersimilar target value. If true, the addon will prioritize targeting enemies with exact matching names first, then partially matching names. |
| //ata bl / blacklist <a / add, r / remove, c / clear> <t / [enemy name]> | Blacklist feature will prevent mobs with names on the blacklist from being tracked by the addon. Invoking with no other parameters will echo out your current blacklist into the chat window. The t parameter will attempt to use the name of your current target for add or remove. Otherwise you can type the enemy name out manually. |
| //ata c / clear | Clears the current enmity list. |
| //ata save | Saves all your settings for the current character. |
| //ata settings | Echoes your current settings into the chat window. |
| //ata barsettings | Echoes your current settings for the visual enemy bars into the chat window. |
| //ata ratbarsettings | Echoes your current settings for the raid assist target bar into the chat window. |
| //ata bar <x [num] , y [num], width [num], visible <t / f>, dist <t / f>, max [num], dir <up / down>> | Changes settings for the visible enemy bars. |
| //ata rat <x [num], y [num], width [num], dist <t / f>, set [name]> | Changes settings for the raid assist target bar. Invoking the command with no parameters will remove the raid assist target. |
| //ata assist / arat | Will attempt to switch your target to whatever enemy your raid assist target last acted upon. |
| //ata next | Selects the next best target according to your settings. |
| //ata nextdiff | Selects the next best target according to your settings that has a different name than your current target. |
| //ata prev | Selects a previous target that was selected by the addon. |
| //ata listnextpage | Scrolls the visible enemy list to the next page if there are more tracked monsters than your max number setting. |
| //ata listprevpage | Scrolls the visible enemy list back to previous pages. |
| //ata setup | Toggles setup mode for the visual elements of the addon. Populates enemy bars and rat bar with dummy data so the user can change settings and see how everything would look. |
| //ata debug <img src="https://i.imgur.com/46b6A21.png">  | Toggles a draggable text box with additional addon information and performance feedback. Select is how long the addon took from the death message of your target being received until it "found" a new target to switch to and injected the incoming packet. Switch is how long it took from the death message of your current target being received until your target arrow actually changed to the new target. (This is the part of the process that's subject to the amount of incoming traffic you have) |

### Setup mode

<img src="https://i.imgur.com/cXCSqDB.png">

### Disclaimer

This addon functions by reading and injecting packets. It will never be as fast as in-game auto target. As far as I can tell, in-game auto target switching is instant because it does not send any information to the server when a new target is chosen. Since the only way I know of to change the player's target with Windower 4 is to inject incoming / outgoing chunks, the speed of the addon switching the target indicator arrow to a new enemy can be dependant on the amount of incoming traffic you have. If the R number in the upper right of the client screen is high, you may experience a delay in your target arrow switching. But this would be exactly the same result if you were trying to switch your target manually when in a high-traffic situation. It's a limitation of the game and there's nothing I can do about it. (Unless the Windower team wants to expose some method for changing your target client-side that does not involve using the network interface)