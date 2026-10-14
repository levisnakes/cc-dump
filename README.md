# cc-dump

Copies every file on a ComputerCraft computer (plus attached disks, minus `/rom`) into one archive and uploads it so you can read it on your PC.

In game:

```
wget https://raw.githubusercontent.com/levisnakes/cc-dump/main/dump.lua dump.lua
dump
```

It prints a link (catbox.moe), or posts the file to your Discord webhook if `/config.lua` sets `DISCORD_WEBHOOK`. A copy is always saved to `/ccdump.txt`.

- `dump catbox` / `dump litterbox` (deleted after 72h) / `dump discord` / `dump local`

On your PC, split it back into folders:

```
python unpack.py https://files.catbox.moe/xxxx.txt
```
