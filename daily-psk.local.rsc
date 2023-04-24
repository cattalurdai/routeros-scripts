#!rsc by RouterOS
# RouterOS script: daily-psk.local
# Copyright (c) 2013-2023 Christian Hesse <mail@eworm.de>
#                         Michael Gisbers <michael@gisbers.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# update daily PSK (pre shared key)
# https://git.eworm.de/cgit/routeros-scripts/about/doc/daily-psk.md
#
# !! Do not edit this file, it is generated from template!

:local 0 "daily-psk.local";
:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:global DailyPskMatchComment;
:global DailyPskQrCodeUrl;
:global Identity;

:global FormatLine;
:global LogPrintExit2;
:global SendNotification2;
:global SymbolForNotification;
:global UrlEncode;
:global WaitForFile;
:global WaitFullyConnected;

$WaitFullyConnected;

# return pseudo-random string for PSK
:local GeneratePSK do={
  :local Date [ :tostr $1 ];

  :global DailyPskSecrets;

  :local Months { "jan"; "feb"; "mar"; "apr"; "may"; "jun";
                  "jul"; "aug"; "sep"; "oct"; "nov"; "dec" };

  :local Month [ :pick $Date 0 3 ];
  :local Day [ :tonum [ :pick $Date 4 6 ] ];
  :local Year [ :pick $Date 7 11 ];

  :for MIndex from=0 to=[ :len $Months ] do={
    :if ($Months->$MIndex = $Month) do={
      :set Month ($MIndex + 1);
    }
  }

  :local A ((14 - $Month) / 12);
  :local B ($Year - $A);
  :local C ($Month + 12 * $A - 2);
  :local WeekDay (7000 + $Day + $B + ($B / 4) - ($B / 100) + ($B / 400) + ((31 * $C) / 12));
  :set WeekDay ($WeekDay - (($WeekDay / 7) * 7));

  :return (($DailyPskSecrets->0->($Day - 1)) . \
    ($DailyPskSecrets->1->($Month - 1)) . \
    ($DailyPskSecrets->2->$WeekDay));
}

:local Seen ({});
:local Date [ /system/clock/get date ];
:local NewPsk [ $GeneratePSK $Date ];

:foreach AccList in=[ /interface/wireless/access-list/find where comment~$DailyPskMatchComment ] do={
  :local IntName [ /interface/wireless/access-list/get $AccList interface ];
  :local Ssid [ /interface/wireless/get $IntName ssid ];
  :local OldPsk [ /interface/wireless/access-list/get $AccList private-pre-shared-key ];
  :local Skip 0;

  :if ($NewPsk != $OldPsk) do={
    $LogPrintExit2 info $0 ("Updating daily PSK for " . $Ssid . " to " . $NewPsk . " (was " . $OldPsk . ")") false;
    /interface/wireless/access-list/set $AccList private-pre-shared-key=$NewPsk;

    :if ([ :len [ /interface/wireless/find where name=$IntName !disabled ] ] = 1) do={
      :foreach SeenSsid in=$Seen do={
        :if ($SeenSsid = $Ssid) do={
          $LogPrintExit2 debug $0 ("Already sent a mail for SSID " . $Ssid . ", skipping.") false;
          :set Skip 1;
        }
      }

      :if ($Skip = 0) do={
        :set Seen ($Seen, $Ssid);
        :local Link ($DailyPskQrCodeUrl . \
            "?scale=8&level=1&ssid=" . [ $UrlEncode $Ssid ] . "&pass=" . [ $UrlEncode $NewPsk ]);
        $SendNotification2 ({ origin=$0; \
          subject=([ $SymbolForNotification "calendar" ] . "daily PSK " . $Ssid); \
          message=("This is the daily PSK on " . $Identity . ":\n\n" . \
            [ $FormatLine "SSID" $Ssid ] . "\n" . \
            [ $FormatLine "PSK" $NewPsk ] . "\n" . \
            [ $FormatLine "Date" $Date ] . "\n\n" . \
            "A client device specific rule must not exist!"); link=$Link });
      }
    }
  }
}
