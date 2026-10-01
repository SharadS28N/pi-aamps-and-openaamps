import paramiko
import os
import sys
import zipfile
import time

PI_HOST = "192.168.18.159"
PI_USER = "aamps"
PI_PASS = "aamps"
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP_PATH = os.path.join(PROJECT_DIR, "piplayer.zip")
PI_REMOTE_ZIP = "/home/aamps/piplayer.zip"
PI_TARGET_DIR = "/home/aamps/pi-aamps-and-openaamps"


def create_project_zip():
    print("[1/4] Packaging project files into piplayer.zip...")
    if os.path.exists(ZIP_PATH):
        os.remove(ZIP_PATH)

    exclude_dirs = {".git", "venv", "__pycache__", ".pytest_cache", ".gemini", ".agents"}

    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(PROJECT_DIR):
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            for file in files:
                if file.endswith(".zip") or file.endswith(".pyc") or file.endswith(".db"):
                    continue
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, PROJECT_DIR)
                zipf.write(file_path, rel_path)

    print(f"      Archive created successfully ({os.path.getsize(ZIP_PATH)} bytes).")


def main():
    print("=" * 60)
    print("   Deploying Aero-Glass White PiPlayer to 192.168.18.159")
    print("=" * 60)

    create_project_zip()

    print("\n[2/4] Connecting via SSH to Raspberry Pi (aamps@192.168.18.159)...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        ssh.connect(PI_HOST, username=PI_USER, password=PI_PASS, timeout=15)
        print("      SSH connection established!")

        print("\n[3/4] Uploading project archive...")
        sftp = ssh.open_sftp()
        sftp.put(ZIP_PATH, PI_REMOTE_ZIP)
        sftp.close()
        print("      Archive uploaded.")

        print("\n[4/4] Extracting & executing installer script on Raspberry Pi...")
        remote_script = f"""
            mkdir -p {PI_TARGET_DIR}
            unzip -o {PI_REMOTE_ZIP} -d {PI_TARGET_DIR}
            rm -f {PI_REMOTE_ZIP}
            cd {PI_TARGET_DIR}
            chmod +x install.sh
            echo '{PI_PASS}' | sudo -S bash install.sh
        """
        
        stdin, stdout, stderr = ssh.exec_command(remote_script, get_pty=True)
        
        while not stdout.channel.exit_status_ready():
            if stdout.channel.recv_ready():
                line = stdout.channel.recv(1024).decode('utf-8', errors='ignore')
                print(line, end="")
            time.sleep(0.5)

        exit_code = stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='ignore')
        print(out)

        print("\n" + "=" * 60)
        if exit_code == 0:
            print("  SUCCESS: Minimalist Aero-Glass PiPlayer is live on your Raspberry Pi!")
            print(f"  Access UI in your browser:  http://{PI_HOST}:8000")
        else:
            print(f"  Deployment finished with exit code {exit_code}")
        print("=" * 60 + "\n")

    except Exception as e:
        print(f"\n[!] Deployment error: {e}")
        sys.exit(1)
    finally:
        ssh.close()
        if os.path.exists(ZIP_PATH):
            try:
                os.remove(ZIP_PATH)
            except Exception:
                pass


if __name__ == "__main__":
    main()
