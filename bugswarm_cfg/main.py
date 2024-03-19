import argparse
import os
import subprocess
import time
import shutil
import requests
from bs4 import BeautifulSoup
import json
import re

# Define the default paths for the sandbox environment on the host and in the container
HOST_SANDBOX_DEFAULT = os.path.expanduser('~/bugswarm-sandbox')
CONTAINER_SANDBOX_DEFAULT = '/bugswarm-sandbox'

def check_valid_artifact(image_tag):
    url = "https://www.bugswarm.org/_datatables/?filter={\"lang\":[\"Java\",\"Python\"],\"build_system\":[\"Maven\",\"NA\"],\"classification\":{\"code\":[\"Yes\",\"Partial\",\"No\",\"NA\"],\"build\":[\"Yes\",\"Partial\",\"No\",\"NA\"],\"test\":[\"Yes\",\"Partial\",\"No\",\"NA\"]}}"

    payload = "{\"query\":\"\",\"variables\":{}}"

    response = requests.request("GET", url, data=payload)
    data = response.json()

    github_artifacts = {}
    flag = False

    for artifact in data:
        if len(str(artifact["failed_job"]["job_id"])) > 8:
            github_artifacts[artifact["image_tag"]] = artifact["failed_job"]["job_id"]
    
    follow_url_base = "https://www.bugswarm.org/artifact-logs"
    
    if image_tag in github_artifacts:
        follow_url = f"{follow_url_base}/{github_artifacts[image_tag]}"
        response = requests.request("GET", follow_url)
        webpage_html = response.text
        soup = BeautifulSoup(webpage_html, 'html.parser')
        match = re.search(r"Image: ubuntu-(\d+\.\d+)", soup.text)

        if match:
            ubuntu_version = match.group(1)
            major_version = int(ubuntu_version.split('.')[0])
            
            if major_version >= 18:
                flag = True
    
    return flag

def ensure_sandbox_environment(host_sandbox=HOST_SANDBOX_DEFAULT):
    """Ensure the sandbox directory exists on the host."""
    if not os.path.exists(host_sandbox):
        os.makedirs(host_sandbox, exist_ok=True)
    print(f"Sandbox directory ensured at: {host_sandbox}")

def pull_docker_image(image_tag):
    """Pull the Docker image from Docker Hub."""
    result = subprocess.run(['docker', 'pull', image_tag], check=True)
    if result.returncode != 0:
        raise Exception(f"Failed to pull Docker image {image_tag}.")
    print(f"Docker image {image_tag} pulled successfully.")

def remove_existing_container(container_name='bugswarm_container'):
    """Remove an existing container with the specified name, if it exists."""
    print(f"Checking for existing container named '{container_name}'...")
    result = subprocess.run(['docker', 'ps', '-aq', '--filter', f'name={container_name}'], capture_output=True, text=True)
    container_id = result.stdout.strip()
    if container_id:
        print(f"Found existing container '{container_name}', removing it...")
        subprocess.run(['docker', 'rm', '-f', container_id], check=True)
        print(f"Container '{container_name}' removed.")
    else:
        print(f"No existing container named '{container_name}' found.")

def run_docker_container(image_tag, host_sandbox=HOST_SANDBOX_DEFAULT, container_sandbox=CONTAINER_SANDBOX_DEFAULT, container_name='bugswarm_container'):
    """Run the Docker container with the specified image, mapping the sandbox environment, and ensure bash is installed."""
    remove_existing_container(container_name)
    # Start the container and ensure it stays running
    result = subprocess.run(['docker', 'run', '-d', '--name', container_name, '-v', f'{host_sandbox}:{container_sandbox}', image_tag, 'tail', '-f', '/dev/null'], check=True)
    if result.returncode != 0:
        raise Exception(f"Failed to start Docker container '{container_name}'.")
    print(f"Docker container '{container_name}' started.")
    # Install bash in the container
    subprocess.run(['docker', 'exec', '-u', 'root', container_name, 'sh', '-c', 'apt-get update && apt-get install -y bash'], check=True)
    print("bash installed in the Docker container.")


def check_container_running(container_name='bugswarm_container'):
    """Check if the 'bugswarm_container' is running."""
    result = subprocess.run(['docker', 'inspect', '--format', '{{.State.Running}}', container_name], capture_output=True, text=True)
    if result.stdout.strip() != 'true':
        raise Exception(f"Container {container_name} is not running.")
    
def get_container_home_directory(container_name='bugswarm_container'):
    """Get the home directory path for the current user in the container."""
    result = subprocess.run(['docker', 'exec', '-u', 'root', container_name, 'bash', '-c', 'echo $HOME'], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    else:
        raise Exception("Failed to determine the container's home directory.")
    
def move_output_to_host(tool, image_tag, script_directory):
    """Move the generated output from the local sandbox to a host directory, handling existing directories."""
    script_path = ""
    if tool == "spoon":
        script_path = "Spoon"
    elif tool == "javaparser":
        script_path = "JavaParser"
    elif tool == "soot":
        script_path = "Soot"
    source_dir = os.path.join(HOST_SANDBOX_DEFAULT, f"{script_path}/{image_tag.split(':')[1]}")
    target_dir = os.path.join(os.getcwd(), f"cfgs/{script_path}/{image_tag.split(':')[1]}")

    # Ensure target directory exists
    os.makedirs(target_dir, exist_ok=True)

    # Function to recursively copy files and directories
    def copy_content(src, dst):
        for item in os.listdir(src):
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            if os.path.isdir(s):
                os.makedirs(d, exist_ok=True)
                copy_content(s, d)
            else:
                shutil.copy2(s, d)

    # Try to copy content
    try:
        copy_content(source_dir, target_dir)
        print(f"Output successfully moved to {target_dir}.")
    except Exception as e:
        print(f"Failed to move output: {e}")

def stop_and_remove_container(container_name):
    """Stop and remove a Docker container."""
    try:
        subprocess.run(['docker', 'stop', container_name], check=True)
        print(f"Container '{container_name}' stopped.")
        subprocess.run(['docker', 'rm', container_name], check=True)
        print(f"Container '{container_name}' removed.")
    except subprocess.CalledProcessError as e:
        print(f"Error stopping or removing container '{container_name}': {e}")


def copy_and_execute_script_directly(tool, image_tag=None, script_directory=None, container_name='bugswarm_container'):
    """Streams the script into the Docker container directly to the home directory's build folder and executes it."""
    script_name = ""
    if tool == "spoon":
        script_name = "spoon.sh"
    elif tool == "javaparser":
        script_name = "javaparser.sh"
    elif tool == "soot":
        script_name = "soot.sh"

    home_dir = get_container_home_directory(container_name)
    build_dir = f"{home_dir}/build"
    
    check_container_running(container_name)

    # Ensure the build directory exists
    subprocess.run(['docker', 'exec', '-u', 'root', container_name, 'bash', '-c', f'mkdir -p {build_dir}'], check=True)
    
    script_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), script_name)
    with open(script_path, 'rb') as script_file:
        subprocess.run(['docker', 'exec', '-u', 'root', '-i', container_name, 'bash', '-c', f'cat > {build_dir}/{script_name}'], stdin=script_file)
    # Fix line endings in the container
    subprocess.run(['docker', 'exec', '-u', 'root', 'bugswarm_container', 'sed', '-i', 's/\r$//', f'{build_dir}/{script_name}'], check=True)
    print(f"Script {script_name} streamed and created in the container's {build_dir} directory.")

    subprocess.run(['docker', 'exec', '-u', 'root', container_name, 'bash', '-c', f'chmod +x {build_dir}/{script_name}'], check=True)
    print(f"Script {script_name} permissions changed to executable in the {build_dir} directory.")

    cmd = f'bash {build_dir}/{script_name}'

    if image_tag:
        cmd += f' {image_tag.split(":")[1]}'
    subprocess.run(['docker', 'exec', '-u', 'root', container_name, 'bash', '-c', cmd], check=True)
    print(f"Script {script_name} executed in the container with image tag '{image_tag}' as the argument, in the {build_dir} directory.")

    # Move the generated output to the host directory
    if script_directory and image_tag:
        move_output_to_host(tool, image_tag, script_directory)

    # Stop and remove the Docker container
    stop_and_remove_container(container_name)


def main():
    parser = argparse.ArgumentParser(description='Run a Docker container with a sandbox environment, copy a script inside it, and execute the script.')
    parser.add_argument('--image-tag', required=True, help='The image tag to use for pulling the Docker image from Bugswarm')
    parser.add_argument('--tool', required=True, help='The tool used for CFG generation')

    script_directory = os.path.dirname(os.path.realpath(__file__))
    container_name = 'bugswarm_container'
    args = parser.parse_args()

    # Concatenate the hardcoded prefix with the user-provided tag part
    full_image_tag = f"bugswarm/cached-images:{args.image_tag}"
    if check_valid_artifact(args.image_tag):
        ensure_sandbox_environment()
        pull_docker_image(full_image_tag)
        run_docker_container(full_image_tag, container_name=container_name)
        copy_and_execute_script_directly(args.tool, full_image_tag, script_directory)
    else:
        print("Incompatible artifact with Bugswarm CFG generator.")

if __name__ == '__main__':
    main()