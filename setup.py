import os
import re
import subprocess
import sys

from setup.cli import query_yes_no
from setup.colorConsole import ColorPrint, cyan, magenta


def print_header():
    header = """
    ###################################################
    #########       Raspi Captive Portal      #########
    #########   A Raspberry Pi Access Point   #########
    #########  & Captive Portal setup script  #########
    ###################################################
    """
    ColorPrint.print(cyan, header)


def check_super_user():
    print()
    ColorPrint.print(cyan, "▶ Check sudo")

    if os.geteuid() != 0:
        print("You need root privileges to run this script.")
        print('Please try again using "sudo"')
        sys.exit(1)
    else:
        print("Running as root user, continue.")


def install_lighttpd():
    print()
    ColorPrint.print(cyan, "▶ Install lighttpd")

    subprocess.run(["rm", "-rf", "/var/lib/apt/lists/"], check=True)
    subprocess.run(["apt-get", "update"], check=True)
    subprocess.run(["apt-get", "install", "-y", "lighttpd"], check=True)


def setup_access_point():
    print()
    ColorPrint.print(cyan, "▶ Setup Access Point (WiFi)")

    print("We will now set up the Raspi as Access Point to connect to via WiFi.")
    print("The following commands will execute as sudo user.")
    print('Please make sure you look through the file "./access-point/setup-access-point.sh"')
    print("first before approving.")
    answer = query_yes_no("Continue?", default="yes")

    if not answer:
        return sys.exit(0)

    subprocess.run("sudo chmod a+x ./access-point/setup-access-point.sh", shell=True, check=True)
    subprocess.run("./access-point/setup-access-point.sh", shell=True, check=True)


def setup_server_service():
    print()
    ColorPrint.print(cyan, "▶ Configure lighttpd and captive portal service")

    # Resolve absolute path once so all config files use consistent paths
    project_dir = os.getcwd()
    lighttpd_config_src = "./lighttpd/lighttpd.conf"

    # Substitute PROJECT_DIR placeholder with the real path
    with open(lighttpd_config_src, "r", encoding="utf-8") as f:
        config = f.read()
    config = config.replace("PROJECT_DIR", project_dir)

    # Write resolved config to a temp file, then copy into place as root
    tmp_conf = "/tmp/portal-lighttpd.conf"
    with open(tmp_conf, "w", encoding="utf-8") as f:
        f.write(config)
    subprocess.run(["sudo", "cp", tmp_conf, "/etc/lighttpd/lighttpd.conf"], check=True)

    # Make CGI scripts executable
    subprocess.run(
        ["sudo", "chmod", "+x",
         os.path.join(project_dir, "server/cgi-bin/ping.sh"),
         os.path.join(project_dir, "server/cgi-bin/admin-disable.sh")],
        check=True,
    )

    print("lighttpd config installed. We will now run setup-server.sh to")
    print("deploy the restore script, configure sudoers, and start the service.")
    print('Please look through "./access-point/setup-server.sh" first.')
    answer = query_yes_no("Continue?", default="yes")

    if not answer:
        return sys.exit(0)

    print()
    print("Enter the admin secret for the disable URL.")
    print("Choose any long, hard-to-guess string — this is your password.")
    admin_secret = ""
    while not admin_secret.strip():
        admin_secret = input("Admin secret: ").strip()
        if not admin_secret:
            print("Secret cannot be empty, please try again.")

    env = os.environ.copy()
    env["ADMIN_SECRET"] = admin_secret

    subprocess.run("sudo chmod a+x ./setup-server.sh", shell=True, cwd="./access-point", check=True)
    subprocess.run("./setup-server.sh", shell=True, cwd="./access-point", check=True, env=env)


def done():
    print()
    ColorPrint.print(cyan, "▶ Done")

    final_msg = (
        "Awesome, we are done here. Grab your phone and look for the\n"
        '"Splines Raspi AP" WiFi (password: "splinesraspi").'
        "\n"
        "When you reboot the Raspi, wait 2 minutes, then the WiFi network\n"
        "and the server should be up and running again automatically.\n"
        "\n"
        "If you like this project, consider giving a GitHub star ⭐\n"
        "If there are any problems, checkout the troubleshooting section here:\n"
        "https://github.com/Splines/raspi-captive-portal or open a new issue\n"
        "on GitHub."
    )
    ColorPrint.print(magenta, final_msg)


def execute_all():
    print_header()
    check_super_user()

    install_lighttpd()
    setup_access_point()
    setup_server_service()

    done()


if __name__ == "__main__":
    execute_all()
