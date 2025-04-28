---
title: 01 - First Install & Configuration
date: 2024-08-18T12:05:00
categories:
  - homelab
  - personal
draft: true
tags:
  - raspbian
  - ssh
  - hardening
---
> [!info]
> Previous Post: [00 - My first note! And a small TODO list :)](first-post.md)
>
> Next Post: [02 - Tailscale & SSH](tailscale.md)
# Installation
The first step to get the raspberry working was to install the OS! I have not researched very deeply into this, but by looking around I think that Raspbian, the official fork of Debian for all Raspberry Pis is the most optimized choice for my case.

I could be wrong though! In fact, one of my first experiments was to configure the OS with BTRFS, and despite succeeding, I had to quickly abandon the project due to the fact that i could not manage to update the initramfs without breaking btrfs support all together, but that's probably for a future post.

That being said, installing Raspbian is actually very easy. I have installed it on top of an SSD, so all I had to do was to plug it in my laptop and run [Raspberry Pi's official imager](https://www.raspberrypi.com/news/raspberry-pi-imager-imaging-utility/).
![](https://www.raspberrypi.com/app/uploads/2020/03/RPI_intro-e1583228263677.png)
## Imager Options
Personally, I don't need a graphical environment (I rarely need to plug an HDMI cable to my Pi to see what's going on, and I can move pretty easily in the terminal), so I've chosen to install Raspberry Pi OS Lite, that ships without an environment. As for other options, I made sure to create the standard user "Pi" with my password, and enabled SSH with password (I will change it later). After countless attempts, however, I learned that the imager can mess things up, and end up *not* enabling SSH, even though I told him to do so.

### Fixing SSH
After flashing Raspbian's image to the SSD, I needed to do a bit of trickery to make sure that SSH is in fact enabled. [The docs](https://www.raspberrypi.com/documentation/computers/remote-access.html#manually) say that to enable SSH manually after flashing the image, I have to add an empty "ssh" file inside the main directory of the boot partition. Easy!

The imager creates two partitions when flashing raspbian, so I need to mount the primary one (`boot`) and proceed with the changes:
```bash
cd /mnt && mkdir raspi
mount /dev/<boot_partition> raspi
cd raspi
touch ssh
cd .. && umount raspi
```
that's about it! Now the SSD is read to be plugged on the Pi!

After giving it a bit of time to boot up, I can login via SSH using:
```bash
ssh pi@<pi_hostname>.local
```
and the first part is done!

## Hardening
Now comes the fun part!

One of the first things that should always be done when configuring a server of any kind is some good old secuirity-hardening! Right now, my Raspberry Pi is very unsafe: I'm logging in with a password to the `Pi` user, that has superuser privileges, and the system is not fully upgraded. So, the first step is easy! Just run `sudo apt update && sudo apt upgrade`

### SSH Hardening
The next step is trickier, but not hard. A safer way to login with SSH to my raspberry would be by using _SSH keys_, and disable password login entirely.

I'll do the key part first. I just need to go to the computer I use to login via SSH and generate a key with
```bash
ssh-keygen
```
and add a strong passphrase. Now I have to let the Raspberry know that my key can be trusted. Doing so does not require to share the private key (it would defeat the security purpose entirely), instead I have to add the _public key_ that was generated in pair with the private one to the `~/.ssh/authorized_keys` of the host. Copy-pasting is bad, so it's better if I use `ssh-copy-id`, like this:
```bash
ssh-copy-id pi@raspberrypi.local -i <path_to_pub_key>
```
If not specified, and if you don't have any other SSH key, the generated pair is `id_rsa` and `id_rsa.pub`, and that's the default key that's used for every SSH key-based connection.

Now I can login by simply typing
```bash
ssh pi@raspberrypi.local
```
but to make it easier, I added a simple configuration to my `~/.ssh/config`:
```
Host pi
	User pi
	RemoteHost raspberrypi.local
	IdentityKey ~/.ssh/id_rsa # this one is technically not needed
```
and now the command is as simple as:
```bash
ssh pi
```
easy!

Now to the server part. To prevent password login (or worse, password login to root user), the file `/etc/ssh/sshd_config` needs to be edited in this way:
1. Uncomment the `PubkeyAuthentication` and set it to `yes`
2. Uncomment the `PasswordAuthentication` and set it to `no`
3. Uncomment the `PermitRootLogin` and set it to `no`
then, just reload ssh with `sudo systemctl restart sshd`

I'd say that's it for now. What could also be done would be setting up a _firewall_ and closing some ports, but I don't see it as a necessity for now, for the simple reason that my raspberry ports are already unreachable from outside my local network. In order to make them reachable, I would need to enable port forwarding on my router for all of them, and it would make absolutely no sense, as the only ports I need open for the outside word are `80` and `443`. Wait: this way I can't login to my Pi from outside home! That's a problem I'll tackle with my post about _Tailscale and SSH_, for now we can stop here :D 
