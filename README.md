# Knife ilo plugin

This plugins aims to ease iLo BMC management.

# Tell me more

Actually, it can be used for 3 actions :
* update iLo firmware
* setup networking on iLo card
* reset iLo (reboot it)

It is linked to the set of attributes we use for a node in Fotolia's chef setup.

Here is the essential stuff
<pre>
$ knife node show foobar.lan -a bootstrap -F json
{
  "bootstrap": {
    "sn": "XXXX",
    "ilo": {
      "password": "S3CRe7",
      "ip": "a.b.c.d",
      "hostname": "ILOXXXX",
      "username": "Administrator"
    },
    "physical_location": {
      "datacenter": "vitry"
    }
    "hostname": "foobar.lan"
  }
}
</pre>

It also needs a configuration file, a sample is provided in the ext/ directory.

# firmware storage

The config file defines the "ilo_firmware_path" where you store the firmwares. It needs to have the following hierarchy :

<pre>
ilo_firmware_path/
|
|-v2/
  |- first.bin
  |- second.bin
|-v3/
  |- foo.bin
....
</pre>

this one is used to avoid naming conflict per iLo version

# Show me !

Reseting an iLo card :

<pre>
[mordor:~] knife ilo reset foobar.lan
About to reset foobar.lan's iLo. is that OK ? (Y/N) [N] y
</pre>

Listing firmwares & upgrading a firmware :

<pre>
[mordor:~] knife ilo firmwares
Firmwares in v3
 * ilo3_120.bin
Firmwares in v2
 * ilo2_213.bin
 * ilo2_215.bin
</pre>

<pre>
[r][mordor:~] knife ilo update foobar.lan ilo2_215.bin --ilo 2
About to update foobar.lan (ilo v2) with the following firmware file. OK ? (Y/N) [N]
</pre>

This will upload, update and then reboot the iLo BMC.

You can also setup fixed network address with this tool. This one is strongly tied to our way to do things, it may not suit your needs.

The configuration is done per-site. Check the config file, it should be self explanatory. It will set the IP address given in the node's attribute. For your first initialization, you can provide the current IP.

Example :
<pre>
[r][mordor:~] knife ilo setup foobar.lan --address a.b.c.d
About to set networking for foobar.lan's iLo. is that OK ? (Y/N) [N]
</pre>

This command allows a "--yes" switch, for your batch updates.

License
=======
3 clauses BSD

Author
======
Nicolas Szalay < nico |at| rottenbytes |meh| info >
