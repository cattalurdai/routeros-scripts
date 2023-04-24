#!rsc by RouterOS
# RouterOS script: collect-wireless-mac%TEMPL%
# Copyright (c) 2013-2023 Christian Hesse <mail@eworm.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# collect wireless mac adresses in access list
# https://git.eworm.de/cgit/routeros-scripts/about/doc/collect-wireless-mac.md
#
# provides: lease-script, order=40
#
# !! This is just a template! Replace '%PATH%' with 'caps-man'
# !! or 'interface wireless'!

:local 0 "collect-wireless-mac%TEMPL%";
:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:global Identity;

:global EitherOr;
:global FormatLine;
:global GetMacVendor;
:global LogPrintExit2;
:global ScriptLock;
:global SendNotification2;
:global SymbolForNotification;

$ScriptLock $0 false 10;

:if ([ :len [ /%PATH%/access-list/find where comment="--- collected above ---" disabled ] ] = 0) do={
  /%PATH%/access-list/add comment="--- collected above ---" disabled=yes;
  $LogPrintExit2 warning $0 ("Added disabled access-list entry with comment '--- collected above ---'.") false;
}
:local PlaceBefore ([ /%PATH%/access-list/find where comment="--- collected above ---" disabled ]->0);

:foreach Reg in=[ /%PATH%/registration-table/find ] do={
  :local RegVal;
  :do {
    :set RegVal [ /%PATH%/registration-table/get $Reg ];
  } on-error={
    $LogPrintExit2 debug $0 ("Device already gone... Ignoring.") false;
  }

  :if ([ :len ($RegVal->"mac-address") ] > 0) do={
    :local AccessList ([ /%PATH%/access-list/find where mac-address=($RegVal->"mac-address") ]->0);
    :if ([ :len $AccessList ] > 0) do={
      $LogPrintExit2 debug $0 ("MAC address " . $RegVal->"mac-address" . " already known: " . \
        [ /%PATH%/access-list/get $AccessList comment ]) false;
    }

    :if ([ :len $AccessList ] = 0) do={
      :local Address "no dhcp lease";
      :local DnsName "no dhcp lease";
      :local HostName "no dhcp lease";
      :local Lease ([ /ip/dhcp-server/lease/find where mac-address=($RegVal->"mac-address") dynamic=yes status=bound ]->0);
      :if ([ :len $Lease ] > 0) do={
        :set Address [ /ip/dhcp-server/lease/get $Lease address ];
        :set HostName [ $EitherOr [ /ip/dhcp-server/lease/get $Lease host-name ] "no hostname" ];
        :set DnsName "no dns name";
        :local DnsRec ([ /ip/dns/static/find where address=$Address ]->0);
        :if ([ :len $DnsRec ] > 0) do={
          :set DnsName [ /ip/dns/static/get $DnsRec name ];
        }
      }
      :set ($RegVal->"ssid") [ /interface/wireless/get [ find where name=($RegVal->"interface") ] ssid ];
      :local DateTime ([ /system/clock/get date ] . " " . [ /system/clock/get time ]);
      :local Vendor [ $GetMacVendor ($RegVal->"mac-address") ];
      :local Message ("MAC address " . $RegVal->"mac-address" . " (" . $Vendor . ", " . $HostName . ") " . \
        "first seen on " . $DateTime . " connected to SSID " . $RegVal->"ssid" . ", interface " . $RegVal->"interface");
      $LogPrintExit2 info $0 $Message false;
      /%PATH%/access-list/add place-before=$PlaceBefore comment=$Message mac-address=($RegVal->"mac-address") disabled=yes;
      $SendNotification2 ({ origin=$0; \
        subject=([ $SymbolForNotification "mobile-phone" ] . $RegVal->"mac-address" . " connected to " . $RegVal->"ssid"); \
        message=("A device with unknown MAC address connected to " . $RegVal->"ssid" . " on " . $Identity . ".\n\n" . \
          [ $FormatLine "Controller" $Identity ] . "\n" . \
          [ $FormatLine "Interface" ($RegVal->"interface") ] . "\n" . \
          [ $FormatLine "SSID" ($RegVal->"ssid") ] . "\n" . \
          [ $FormatLine "MAC" ($RegVal->"mac-address") ] . "\n" . \
          [ $FormatLine "Vendor" $Vendor ] . "\n" . \
          [ $FormatLine "Hostname" $HostName ] . "\n" . \
          [ $FormatLine "Address" $Address ] . "\n" . \
          [ $FormatLine "DNS name" $DnsName ] . "\n" . \
          [ $FormatLine "Date" $DateTime ]) });
    }
  } else={
    $LogPrintExit2 debug $0 ("No mac address available... Ignoring.") false;
  }
}
