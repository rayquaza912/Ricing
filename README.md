# GnuPG Messages Manager


#### Gpg-messages-manager is an interactive bash script that lets you manage messages and recipients for use with GnuPG. It uses [FZF](https://github.com/junegunn/fzf) as a dependency. Here are the available options :

* Show GPG keyring
* Generate a new key pair
* Import a public key
* Remove a public key
* Encrypt your address
* Encrypt a message
* Decrypt a message

The architecture of your `gpgDir` must match this tree in order to make the utility working.
```
.
├── asc
│   ├── adr_for_antoine.asc
│   ├── adr_for_aurelien.asc
│   ├── msg_for_antoine_20191015_182013.asc
│   ├── msg_for_antoine_20191015_203924.asc
│   ├── msg_for_aurelien_20191023_013644.asc
│   └── msg_for_aurelien_20191202_013102.asc
├── pub
│   ├── polandteam_pub.asc
│   ├── grenouille_rouge.asc
│   └── madeingermany_pub.asc
└── txt
    ├── adr.txt
    ├── msg_for_antoine_20191015_203924.asc.txt
    ├── msg_for_antoine_20191107_165132.asc.txt
    └── msg_for_antoine_20191108_141425.asc.txt
```

By default, it refers to `~/Documents/pgp/`, where
* `asc` is your encrypted files folder, such as addresses or messages in plain ASCII PGP.
* `pub` is where you put yout recipients public key.
* `txt` is your decrypted messages folder. It also contains your plain addresse text.

Here is the common output when you launch the script :

```
Welcome to GnuPG !

[1] Show keyring
[2] Generate a new public key
[3] Import a public key
[4] Remove a public key
[5] Encrypt your address
[6] Encrypt a message
[7] Decrypt a message

[0] Exit

>>>

```

