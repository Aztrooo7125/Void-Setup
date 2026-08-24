### DISCLAIMER : THIS SETUP IS FITTED TO MY VERY OWN PERSONAL USE AND EXPERIENCE

This is a very minimal void installation setup, made for instant setup of the nitty-gritty stuff and made to be plug and play after the initial install.

It uses niri and has only a screen without waybar/status bar, status depends on terminal, and most other things depend on terminal and pure niri shortcuts aswell.

---

### Initial Steps After Bare Install
1. Connect internet (recommended using ethernet connection).
1. Run the **xbps-install -Sy xbps**
1. Then update the xbps package manager using **xbps-install-Syu**
1. Install **git** and **python** by running **xbps-install -Syu git python3**
1. Generate SSH key using **ssh-keygen** to then link to your Github profile: **ssh-keygen -t ed25519 -C "your_email@example.com"**
1. Go to your generated SSH key folder then copy the **id_ed25519.pub** to your GitHub profile, or alternatively an easier way is to run **cat id_ed25519.pub > index.html; python3 -m http.server 8000; rm index.html**

####NOTE: USE A PRIVATE NETWORK AS PEOPLE COULD EASILY GET YOUR SSH KEY WHILE THE SERVER RUNS!

7. Run **git clone https://github.com/Aztrooo7125/Void-Setup.git**

1. Run the "void_setup.sh" script.