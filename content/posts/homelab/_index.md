---
title: 00 - My first note! And a small TODO list :)
date: 2024-08-17T00:00:00
categories:
  - homelab
  - personal
draft: false
---
> [!info]
> Next Post: [01 - First Install & Configuration](installation.md)
# Hello world
Hi all! 
This is my first post on a series that I hope will be pretty long about the various stuff that I experiment with in my homelab! I like to call it that way, but at the time of writing (august 2024) it still consists of a VERY modest Raspberry Pi 4 that I got gifted for my birthday; but it still does an amazing jobs at providing a space for testing new things out. Eventually I would like to upgrade to something more decent, but for now that's the money I can afford to spend on such a side project (that is, 0 :D)

At the time of writing I've already worked for I'd say one year on this small project, so I'm not a total novice and the first couple of posts will be about keeping up my journal for stuff that I have already done. However, at the end of the page I will also provide a small TODO list of stuff that I have not yet had time to implement / research / understand fully, and would like to try.
## Why a Homelab?
That's a great question, if you asked it! Personally, I'm the type of person who's more comfortable in learning by experimenting and trying new stuff. My inspiration for the first projects came from the curiosity of learning how the hell various technologies such as Docker, a reverse proxy, a WAF and various other things worked, and the fun part about maintaining a homelab is that all of the projects that you can build on top of that bring in more ideas and questions than answers, and thus it's like a never ending project!
## My hardware setup
As I've already said, at the time my hardware consists only of a [Raspberry Pi 4](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/), running on [Raspbian](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/) (which I'm not particularly proud of using, but as of now I've not researched enough into the topic to find a valid replacement...) installed on an external SSD, and that's it!
There will be a couple of posts that are going to talk about various IOT devices that I also use, but I wouldn't count them inside the "hardware" part of the homelab itself.
If I ever manage to upgrade this very cheap setup, I hope that my future me will have the wisdom to come back here and write a small update v.v

That's all for the start! The next posts will be about how I set up the whole device for starting, while down here I'm leaving a small TODO list of things I have done and journaled / not yet journaled / plan to do / plan to research. See ya!
## The TODO List
### Finished Projects
- [Raspbian Installation & Initial Configuration](installation.md)
- [Tailscale + SSH](tailscale.md)
- Docker Installation _(not journaled yet)_
- Updates & Watchtower _(not journaled yet)_
- Dynamic DNS & Cloudflare _(not journaled yet)_
- Reverse Proxy _(not journaled yet)_
- Portainer & Versioning _(not journaled yet)_
- Homeassistant Installation _(not journaled yet)_
- Pihole & Tailscale for DOH _(not journaled yet)_
- Cloud with Seafile _(not journaled yet)_
### Work in Progress

|                                                  | Status        | Notes                                                                                                 |
| ------------------------------------------------ | ------------- | ----------------------------------------------------------------------------------------------------- |
| Updates & Watchtower                             | _Almost Done_ | Missing the part relative to apt auto-upgrades                                                        |
| IOTS Integration<br>(will be divided eventually) | _Expanding_   | I always have new IOT devices / ideas that i come up with, so this is almost a "never ending" project |
### Future Ideas
> [!info] Sorted by priority

|                                                                     | Research Stauts | Notes                                                                                                                                                                            |
| ------------------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Borgbackup Automation                                               | _Started_       | This has 100% of the priority right now, don't want my whole setup to blow away (and using TARs isn't practical)                                                                 |
| MQTT broker for IOT devices                                         | _Not started_   | Could make sense to look into this to secure IOT devices maybe?                                                                                                                  |
| Books & Calibre                                                     | _Advanced_      | Need to understand if there are better alternatives to Calibre, which there might                                                                                                |
| Moving to BTRFS                                                     | _Stalled_       | I still need to figure how to fix some initramfs update problems, and it's pretty hard to experiment                                                                             |
| Budget App                                                          | _Not started_   | I want to be extra careful to choose something that's extremely security rock-solid                                                                                              |
| Kobo Modding                                                        | _Not started_   | Not particularly homelab-related, but I've heard that they can be modded extremely easily and can even be turned into a small fully-customizable monitor. Need to look into this |
| Move Tailscale ACLs to GitOps, maybe add tests(?), general revision | _Not started_   | https://tailscale.com/kb/1204/gitops-acls                                                                                                                                        |
