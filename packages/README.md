# Package snapshot

This directory holds a snapshot of explicitly installed packages (`pacman -Qqe`),
including AUR packages. It lets you restore your whole system software after a
fresh install:

```sh
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
paru -S --needed $(cat packages/pkglist.txt)
```

To update the snapshot after installing new packages:

```sh
pacman -Qqe > packages/pkglist.txt
```
