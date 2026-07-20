---
title: "Hardware, Placing and Routing"
date: 2026-07-20T07:28:08Z
draft: false
categories: [homelab]
---

# Placing components around the House

Specifying tasks for each component of my homelab is just half the hustle. The other main problem is understanding how I could place them in my house.

## Bypassing room locations

Just to give a bit of context (without doxxing myself too much): my house does not have cabled Ethernet, meaning that I have no way of connecting my hosts to my router if I were to put them in another room. However, there is no way I could manage placing all components in the same place without having my family kill me (my router is placed in my living room and barely fits there). So, how can I get around this problem?

The best solution would be to buy some [mesh Wi-Fi devices](https://en.wikipedia.org/wiki/Wireless_mesh_network), which effectively "replicate" my router's Wi-Fi in the different places where they are put. This way, if I were to put my Lenovo laptop in a different room from the modem, I could attach a mesh device, connect it to my house's Wi-Fi and link it to my laptop via Ethernet. This is the best solution because it requires minimal latency compromises and effectively adds another AP for the same Wi-Fi in another location.

![An example of a mesh network](./mesh.jpg "An example of a mesh network")

However, mesh devices can cost a bit, and I have to admit that I didn't consider this solution originally, which is why I had to fall back on a second, less-reliable option. In my case, the architecture is similar to that with mesh devices, but instead of using them I would put a [Wi-Fi repeater](https://en.wikipedia.org/wiki/Wireless_repeater) to replicate my router's signal in another room, and then link it to my laptop, again, with an Ethernet cable. This is a suboptimal solution, of course, since the replicated Wi-Fi is different from the original one, and there is no way to create VLANs to segment the network via wireless, but it will do for now.

## Routing

The use of a repeater/mesh device only solves the problem at the _physical_ level. However, we still have to solve the part about routing rules.

### Switch

For homelabs, it is typically suggested to [segment the network](https://en.wikipedia.org/wiki/Network_segmentation) into logically separate units: this means that if a homelab device is compromised, an attacker cannot reach user devices on the original home network (which is the one actually providing connectivity). This separation is usually achieved using [VLANs](https://en.wikipedia.org/wiki/VLAN), which are logical network units that separate a network into smaller parts. VLANs are usually implemented by adding a small "tag" to a packet, which is then read by either a router or a switch and routed to the correct VLAN.

![How VLANs work with different switches and a router. In my case, I have just one router and one switch](./vlan.png "How VLANs work with different switches and a router. In my case, I have just one router and one switch")

In my current setup, it is impossible to implement network segmentation at the wireless level using VLANs, because repeaters generally (and mine specifically) are not built to support them. This means that I have to assume that the connection coming from the repeater is virtually a continuation of my home network, which means that there is _no segmentation_. If I were to connect the repeater to the Wi-Fi, I would thus be able to link only one device via Ethernet, and the network would look something like this:

{{< mermaid >}}
flowchart LR
    router[Home router] -->|Wi-Fi| repeater[Wi-Fi repeater]
    repeater -->|Ethernet| lenovo[Lenovo PC]
{{< /mermaid >}}

In order to "multiplex" the Ethernet connection to allow linking multiple hosts, I had to add a small [TP-Link switch](https://www.tp-link.com/it/home-networking/range-extender/tl-wa850re/) with 8 ports, a Gbit connection, and VLAN support. Adding the Ethernet connection makes the network evolve into this logical representation:

{{< mermaid >}}
flowchart LR
    router[Home router] -->|Wi-Fi| repeater[Wi-Fi repeater]
    repeater -->|Ethernet| switch[TP-Link switch]
    switch -->|Ethernet| lenovo[Lenovo PC]
    switch -->|Ethernet| pi5[Raspberry Pi 5]
    switch -->|Ethernet| pi4[Raspberry Pi 4]
{{< /mermaid >}}

### VLANs

Right now, however, the network is still _not_ segmented: I have just extended the repeater to connect multiple devices. I could start segmentation by adding VLANs behind the switch: I decided to allocate VLAN ID 10 for the Lenovo PC and the Pi 5 (since we said that they have to be able to communicate). The Pi 4 (which will be connected, in the future, to all IoT devices in the house) will get a separate network with ID 20:

{{< mermaid >}}
flowchart TD
    router[Home router] -->|Wi-Fi| repeater[Wi-Fi repeater]
    repeater -->|Untagged Ethernet| switch[TP-Link switch]
    subgraph vlan10[VLAN 10: Homelab]
        lenovo[Lenovo PC]
        pi5[Raspberry Pi 5]
    end
    subgraph vlan20[VLAN 20: IoT]
        pi4[Raspberry Pi 4]
    end
    switch -->|Access port: VLAN 10| lenovo
    switch -->|Access port: VLAN 10| pi5
    switch -->|Access port: VLAN 20| pi4
{{< /mermaid >}}

### pfSense

This setup is already good enough, but one of my ideas for experimenting with this lab was to try messing around with open-source solutions for routing. This is both because it seems very interesting and because my ISP's router is hot garbage, which doesn't allow me to do almost anything. The idea to "replace" it is pretty simple: I would use the Lenovo to host a VM with a [pfSense](https://www.pfsense.org/) installation, which would act as the "entry point" for my homelab. Then, since my home network does not need to expose anything to the wider internet, I can insert this router's VM in a [demilitarized zone](https://en.wikipedia.org/wiki/DMZ_(computing)), which has two big advantages:

1. This effectively isolates the router from the rest of my home network, achieving hard segmentation
2. If I were to, in the future, decide to expose a new service on a new VM/port, I don't need to deal with [double-NAT shenanigans](https://kb.netgear.com/it/30186/Cos-%C3%A8-Double-NAT-e-perch%C3%A9-%C3%A8-cattivo). Since the DMZ settings make my ISP's router route all the traffic coming from the home network's public IP to pfSense, I just need to set up NAT on the router for the specific machine hosting the service.

This means that my final network configuration will be the following:

{{< mermaid >}}
flowchart TD
    subgraph home[Home network: 192.168.0.0/24]
        router[ISP router] -->|Wi-Fi| repeater[Wi-Fi repeater]
        router --> home_devices[Home devices]
    end

    subgraph homelab[Homelab networks]
        subgraph lenovo[Lenovo PC: Proxmox host]
            proxmox[Proxmox]
            pfsense[pfSense VM<br/>WAN: 192.168.0.x<br/>VLAN 10 gateway: 192.168.10.1<br/>VLAN 20 gateway: 192.168.20.1]
        end
        switch[TP-Link switch]
        subgraph vlan10[VLAN 10: 192.168.10.0/24]
            docker[Docker VM on Lenovo Proxmox<br/>Homelab services]
            pi5[Raspberry Pi 5]
        end
        subgraph vlan20[VLAN 20: 192.168.20.0/24]
            pi4[Raspberry Pi 4<br/>IoT services]
        end
    end

    repeater -->|WAN / DMZ| pfsense
    pfsense -->|LAN trunk| switch
    switch -->|Access port| docker
    switch -->|Access port| pi5
    switch -->|Access port| pi4
{{< /mermaid >}}

This setup almost entirely works: there is still one last problem that needs to be solved, and that is the Pi 4 segmentation. Currently, the diagram shows that the Pi with Home Assistant is isolated from the home network containing the home devices. In order to let Home Assistant bypass this isolation, pfSense needs to be configured with a firewall rule that allows connections only from the Pi to a whitelisted list of IoT device IPs.

## Wrapping Up

In the next post I will go into more detail on how this routing will be set up: I will install Proxmox on my Lenovo PC and spin up a pfSense VM manually, then proceed to configure it. In the future I will go back to the setup phase to make it declarative using a combination of OpenTofu and Ansible.
