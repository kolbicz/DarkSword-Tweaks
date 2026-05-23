# DarkSword / RemoteCall Tweaks

This repository contains some iOS 18 **DarkSword / RemoteCall** tweaks I created for personal use.

Since there is no full jailbreak in sight for iOS 18, I tried to implement some of my favorite tweaks using RemoteCall. The possibilities are limited, but I was surprised by how much is still possible.

## Compatibility

These tweaks have been tested on **iOS 18**. They might also work on **iOS 17** and up to **iOS 26.0.1**, since DarkSword itself supports that range — I do not have test devices for those versions, so this is unconfirmed.

## License / Permission to Use

Anyone is free to use, modify, port, or convert these tweaks for any purpose, including integrating them into other projects such as **Lara** or **Lightsaber**.

## Compiled IPA Files

I do not plan to provide compiled IPA files, as there are already several projects available for that purpose, such as **Lightsaber**, [**Cyanide**](https://github.com/zeroxjf/cyanide-ios) — which already includes most of these tweaks — and [**Lara**](https://github.com/rooootdev/lara).

## Base Project

My tweaks are based on the following project:

[https://github.com/wh1te4ever/darksword-kexploit-fun/tree/main/darksword-kexploit-fun](https://github.com/wh1te4ever/darksword-kexploit-fun/tree/main/darksword-kexploit-fun)

I used this project because Lara did not work for me, and Lightsaber does not support iOS 18.7 — which is the version my main test device runs on.

## Usage

To implement these tweaks yourself:

1. Clone the project by [wh1te4ever](https://github.com/wh1te4ever/darksword-kexploit-fun).
2. Add the code and helper functions to `ViewController.m` or to an external file.
3. Call the function inside `- (void)viewDidLoad` **after** `kexploit_opa334();`.

```objectivec
- (void)viewDidLoad
{
    [super viewDidLoad];

    kexploit_opa334();

    // Call your tweak function here
    my_tweak_function();
}
```

## Credits

Credits go to:

- [wh1te4ever](https://github.com/wh1te4ever)
- [opa334](https://github.com/opa334)
- [zeroxjf](https://github.com/zeroxjf)
- Claude
- All the developers of the original tweaks, which I shamelessly decompiled.
