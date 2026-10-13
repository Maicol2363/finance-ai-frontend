# Finance AI app icon

`finance-ai-app-icon.png` is the ChatGPT Image generated brand artwork and the
canonical icon source (512 px). It was generated from the product's established
identity: forest emerald, cream wallet, amber rising coin, and the expense
receipt that represents photo, voice, and text capture. The wallet and upward
coin retain the team's existing visual direction; the receipt ties it to the
product's capture flow. No generic AI symbol or university emblem is used.

Android launcher images, the Windows ICO, and web icons are resized from this
source. Interface icons use Lucide from `lucide_icons_flutter` (MIT license).
To regenerate platform icons from the `finance-ai-frontend` directory:

```sh
magick assets/branding/finance-ai-app-icon.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick assets/branding/finance-ai-app-icon.png -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick assets/branding/finance-ai-app-icon.png -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick assets/branding/finance-ai-app-icon.png -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick assets/branding/finance-ai-app-icon.png -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
magick assets/branding/finance-ai-app-icon.png -define icon:auto-resize=256,128,64,48,32,16 windows/runner/resources/app_icon.ico
```
