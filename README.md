# fedora-mod
This script will automate the install of all the drivers fonts and programs that I use on my Daily Driver/Gaming rig/Tablets.
This is divided into sections so you can install only what you need.


### Notes:
- Simply install fedora first then run this after.

#### *** These scrips must be ran in order. Any deviation will break your system. The "nvidia.sh" "Surface.sh" and "testing.sh" scripts are hardware based/optional. ***
  
- "1.sh" will install applications, fonts, cursors, etc.

- "2.sh" will customize gnome settings.

- "Surface.sh" will install the necessary drivers to get a Microsoft Surface running on Fedora (skip if not a Microsoft Surface Device).

- "hyprland-setup" will install hyprland on your Fedora system.
  
- If you have multiple hard drives in your system, after you run all the scripts, edit your fstab to auto-mount your drives on boot.


 
### To install:

1. Run

``` git clone https://github.com/PiercingXX/fedora-mod ```


3. Change Mod:

``` chmod -R u+x fedora-mod/ ```


4. cd into install folder:

``` cd fedora-mod ```


5. Run the first script:

``` sudo ./1.sh ```


6. After the system reboots open Terminal:

``` cd fedora-mod ```

``` ./2.sh ```


### **Optional** 


7. Beautiful Bash:

``` git clone https://github.com/christitustech/mybash ```

``` cd mybash ```

``` ./setup.sh ```


11. If you are using a Microsoft Surface device you can now run the script:

``` sudo ./Surface.sh ```


13. If you want to run Hyprland run:

``` sudo ./hyprland-setup.sh ```

If you come across any issues please let me know.



