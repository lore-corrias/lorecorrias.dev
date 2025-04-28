---
title: 02 - Tailscale & SSH
categories:
  - homelab
  - personal
draft: true
date: 2024-08-18T17:13:00
tags:
  - tailscale
  - vpn
  - ssh
---
> [!note]
> Previous post: [01 - FIrst Install & Configuration](installation.md)
# What is Tailscale, and why use it anyway?
[Tailscale](https://tailscale.com/) is a service that provides a very easy to use VPN to connect various devices without having to expose them to the internet. For now, my Raspberry Pi is rather secure, but lacks flexibility: if I leave my house and, say, go to work, how would I be able to access the services that I configured?
## A security approach
One possible answer to this dilemma is to simply **expose your service**: if you want to be able to access your machine from outside the LAN, well, just configure [port-forwarding](https://en.wikipedia.org/wiki/Port_forwarding) on your router for port `22` and congrats, you just made your Pi accessible for literally **anyone on the Internet**! Well, sort of. I mean, if an attacker wants to try and [ssh-bruteforce](https://www.linuxfordevices.com/tutorials/linux/hydra-brute-force-ssh) his way in my homelab he would still need its IP address, but that's really trivial to get if I am exposing, say, a website, since all it's needed is a simple `ping`. Also, exposing a service like SSH is not necessarily bad if we've taken precautions against most of the "low-hanging-fruit" attacks (such as bruteforces with SSH keys), but since you can never know what kind of vulnerabilities or other attacks of the sort could expose your SSH service, I like to adopt the strategy of [defense in depth](https://en.wikipedia.org/wiki/Defense_in_depth_(computing)), following the reasoning that SSH is an _extremely sensitive service_: it can sandboxed, of cource (allowing to SSH with users that have no permission whatsoever and can't do damage), but for a skilled attacker it's not really hard to privilege-escalate starting from a compromised machine, so I prefer to not run the risk.

Here's where the second approach comes to help: just make the services accessible, but only for specific users or under specific conditions, using Tailscale to help you. Tailscale allows you to configure a "private network" (that is not "phisically real", but "_virtual_", thus the name) of devices, which can communicate between them as if they were part of a single _LAN_, meaning that all of the devices which are not specifically allowed to enter the network cannot communicate with those that are inside it. This way, we don't need no port forwarding whatsoever: just connect the Pi and your computer to Tailscale, and then connect via SSH as if you were inside the same LAN! Of course, this can be done with any service, even web-based ones, and Tailscale makes it ridiculously easy to fine-grain your configuration to even the most remote edge case.
### Compromises & Defense in Depth
The point is: security is always about compromises. Don't want to run any sort of risk regarding the SSH attack surface? No problem, you can just disable SSH entirely and access your Pi with your keyboard, but that's extremely impractical. Want no pain whatsoever, including the hassle of managing and storing SSH keys? Then go for it, port forward and set your user's password as something like "1234", but then good luck defending your Pi.

In my case, I have decided that there are basically two group of people that need to access my Pi: 
* _my family_, that might want to use some services but don't want to install too many additional configurations or study complex security strategies
and then there's
* **me**, the main maintainer of the lab (maybe in the future there will be someone else, but for now it doesn't seem likely at all), and for me running and configuring Tailscale on my devices is definitely not a problem whatsoever, actually, if I learn something new in the process it becomes a gain.

In this case, SSH is a perfect candidate to be "hidden" behind VPN, since it provides an extra layer of security (only authorized members in Tailscale can access the Pi with the VPN) and is really easy to configure and integrate in my workflow. Depending on my level of paranoia and fear, I will from now on always consider, for each new service, whether or not I want it to be open to the public, or want to make it accessible only via VPN. _Just as a note, I tend to be more on the "paranoid" end of the spectrum generally :)_

That being said, now I can finally make a deeper dive inside the word of Tailscale!
# Configuring Tailscale
The first thing you need, like everything that's not self-hosted, you need an account to register to Tailscale's service. Technically speaking, and this could be part of a future project, Tailscale allows you to host your own server, called [Headscale](https://headscale.net/), but for now the hosted version is what I'm going for.

Once you login, you already have your VPN! You can start by connecting your devices to it by installing Tailscale in each of them. For the raspberry, you can use Tailscale's official [installation script](https://tailscale.com/download); then, you just need to enable the service and login:
```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo tailscale up
```
And now you should be able to see your device on the "machine" tab of Tailscale. All you need to do now is follow the same procedure for each device that you want to be connected to your virtual network. If you need help, just follow the official [instructions](https://tailscale.com/kb/1316/device-add).

From now on, each added device will have an unique IP address that you can use for communications, but by default Tailscale uses [MagicDNS](https://tailscale.com/kb/1081/magicdns), which means that each device also has a DNS record (usually consisting of his hostname), that can be used instead of the address. This means that, now, connecting to our Raspberry from outside our network (if we are connected to Tailscale, of course), is as simple as running:
```bash
ssh pi@pi -i <identity_key>
```
where "`pi`" is the hostname that is used as a DNS record. But we can do better! We don't want to have to manage our identity keys for each device, and surprisingly Tailscale can help us!
## Tailscale SSH
If you think about it, my authentication is kind of redundant right now. SSH authorization keys have the purpose of "identifying" a host and verifying that he actually has the required permissions to access the machine, but once I finished setting up Tailscale each machine inside the network has its unique identifier (its IP address/hostname/magicDNS entry), and assuming that we only want to limit access to our Raspberry to people inside our virtual network, then we now have two distinct identification mechanism that could be unified as one: for example, by allowing all users coming from inside the Tailscale network to access automatically. That would still be secure, because:
1. Each user needs to be logged in to its Tailscale account
2. The Tailscale account must be part of the same network
but can we do this using Tailscale? [Yes](https://tailscale.com/kb/1193/tailscale-ssh)! In fact, we can even configure a set of rules that regulate which users can access to which devices and how.

The first step to start is to enable Tailscale on our Pi with a slightly different command:
```bash
sudo tailscale up --ssh
```
This way, we are notifying to the network that the Raspberry Pi allows for SSH connections using Tailscale (the specifics are better explaind on [this](https://tailscale.com/kb/1193/tailscale-ssh#ensure-tailscale-ssh-is-permitted-in-acls) page). But we might not want to allow each device on the network to be able to connect to the Pi, and in order to limit this possibility we need to edit Tailscale's ACLs. To do so, go to the "Access Control" panel of Tailscale and start editing!

My goal is to create a structure like this:
- A first group of devices, called "`lore-devices`", contains each device that needs to connect to the Pi.
- A second group of device(s), called `raspberrypi`, that contains one single element (the Raspberry Pi).
- I want to allow any connection from members of the `lore-devices` group to the `raspberrypi` group, but want to limit access to a non-superuser `docker` (which does not exist yet, but will be described later).

So, my ACL looks something like this:
```json
{
	// Define the tags which can be applied to devices and by which users.
	"tagOwners": {
		"tag:lore-devices": ["autogroup:admin"],
		"tag:raspberrypi":  ["autogroup:admin"],
	},

	// Define access control lists for users, groups, autogroups, tags,
	// Tailscale IP addresses, and subnet ranges.
	"acls": [
		{
			"action": "accept",
			"src":    ["*"],
			"dst":    ["*:*"],
		},
	],

	// Define users and devices that can use Tailscale SSH.
	"ssh": [
		// Allow all users to SSH into their own devices in check mode.
		// Comment this section out if you want to define specific restrictions.
		{
			"action": "accept",
			"src":    ["tag:lore-devices"],
			"dst":    ["tag:raspberrypi"],
			"users":  ["docker"],
		},
	],
}
```
This configuration is really simple (and stupid), but will do its job for now! Save the changes and then add manually each device to its group (by clicking on the three dots -> "edit acls tags").

That's it! Now connection to our Pi is as easy as ever, since we can run this command from any device inside the Tailnet:
```bash
ssh docker@pi
```
and connect automatically, without any ssh key needed! I would still suggest to leave one in case there are some Tailscale problems and you need to connect locally, but that's my take.

See you on the next post!
