# Coach Ba

## Overview

The **Coach Ba** software is a Bash-based testing environment that allows users to take tests on various topics. It consists of three main components:

- **Client (`cbc.sh`)**: A script that interacts with the user, sends commands to the server, and displays results.
- **Server (`cbs.sh`)**: A script that manages the test session, processes user commands, validates answers, and calculates results.
- **Library (`cbl.sh`)**: A Library of common functions for client and server.

The project is designed to be modular, secure, and extensible, with all questions, answers, and user results stored in separate files.

## TOC

- [Coach Ba](#coach-ba)
  - [Overview](#overview)
  - [TOC](#toc)
  - [Features](#features)
    - [General](#general)
    - [Client (`cbc.sh`)](#client-cbcsh)
    - [Server (`cbs.sh`)](#server-cbssh)
  - [Command Line Interface](#command-line-interface)
    - [Server CLI (`cbs.sh`)](#server-cli-cbssh)
    - [Client CLI (`cbc.sh`)](#client-cli-cbcsh)
  - [Installation](#installation)
    - [Manual Installation](#manual-installation)
    - [Automated Installation with deploy.sh](#automated-installation-with-deploysh)
      - [Prerequisites](#prerequisites)
      - [Running the Deployment](#running-the-deployment)
      - [What deploy.sh Does](#what-deploysh-does)
      - [Post-Deployment](#post-deployment)
      - [Configuration Files](#configuration-files)
  - [Usage](#usage)
    - [File Structure](#file-structure)
    - [Logging](#logging)
  - [Security](#security)
  - [License](#license)
  - [Authors](#authors)
  - [Acknowledgments](#acknowledgments)

## Features

### General

- Communication between the client and server is handled via named pipes.
- Supports multiple question types:
  - **One-choice**: Select one correct answer.
  - **Multiple-choice**: Select multiple correct answers.
  - **Text-based**: Enter the correct word(s).
- Secure file handling with proper permissions.
- Logging functionality with three verbosity levels (`-v`, `-vv`, `-vvv`, `-vvvv`, `-vvvvv`).

### Client (`cbc.sh`)

- Handles user input and sends commands to the server.
- Receive and display answers from the server.
- Displays course information, test start time and progress.

### Server (`cbs.sh`)

- Manages test sessions and validates answers.
- Supports time-limited and non-time-limited modes.
- Calculates the final result as a percentage of correct answers.
- Stores user results in a file with the format: `user_topic_yyyymmdd_hhmm`.
- Provides immediate feedback on answers or final results at the end of the session.
- Handles unexpected scenarios, such as missing files or crashes.

## Command Line Interface

### Server CLI (`cbs.sh`)

The server script supports the following command-line options:

```bash
./cbs.sh [OPTIONS]
```

**Options:**

- `-u <username>`: Specify the username for the test session (overrides CB_USERNAME environment variable)
- `-t <topic>`: Specify the topic/course code (overrides CB_TOPIC environment variable)
- `-l <minutes>`: Set time limit for the test session in minutes
- `-r`: Run in coach mode with no time limitation
- `-v`: Enable verbose logging (CRIT level)
- `-vv`: Enable more verbose logging (ERR level)
- `-vvv`: Enable detailed logging (WARNING level)
- `-vvvv`: Enable info logging (INFO level)
- `-vvvvv`: Enable debug logging (DEBUG level)
- `-h`: Display help information

**Examples:**

```bash
# Start server in coach mode with no time limit
./cbs.sh -r

# Start server for specific user with 30-minute time limit
./cbs.sh -u student1 -l 30

# Start server with verbose logging
./cbs.sh -u student1 -r -vvv

# Start server with specific topic and time limit
./cbs.sh -u student1 -t PLLB10001001 -l 45
```

### Client CLI (`cbc.sh`)

The client script supports the following command-line options:

```bash
./cbc.sh [OPTIONS]
```

**Options:**

- `-u <username>`: Specify the username for connecting to the server (overrides CB_USERNAME environment variable)
- `-t <topic>`: Specify the topic/course code (overrides CB_TOPIC environment variable)
- `-v`: Enable verbose logging (CRIT level)
- `-vv`: Enable more verbose logging (ERR level)
- `-vvv`: Enable detailed logging (WARNING level)
- `-vvvv`: Enable info logging (INFO level)
- `-vvvvv`: Enable debug logging (DEBUG level)
- `-h`: Display help information

**Examples:**

```bash
# Start client with default settings
./cbc.sh

# Start client for specific user
./cbc.sh -u student1

# Start client with specific topic and verbose logging
./cbc.sh -u student1 -t PLLB10001001 -vv

# Start client with debug logging
./cbc.sh -vvvvv
```

**Interactive Commands (once client is running):**

- `s`: Start the test session
- `t`: Display remaining time or test start time
- `l`: List all questions
- `p`: Display progress (answered and marked questions)
- `<number>`: Request a specific question by its number (e.g., `1`, `15`)
- `a`: Submit an answer
- `r`: Mark current question for answering later
- `f`: Finish the session and calculate results
- `q`: Quit the session

## Installation

### Manual Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/your-repo/coach_bash.git
    cd coach_bash
    ```

2. Set up the environment:
   - Create a .env file to define default values for CB_USERNAME and CB_TOPIC
   - The CB_PW value is populated after running the deploy.sh

   ```bash
   export CB_USERNAME=user
   export CB_TOPIC=PLLB10001001
   export CB_PW=password
   ```

3. Ensure the required files are available:
    - `courses/course.txt`: Contains questions and answers.
    - `courses/course.des`: Contains course descriptions.

4. Set executable permissions for the scripts:

   ```bash
   chmod +x cbc.sh cbs.sh
   ```

### Automated Installation with deploy.sh

The `deploy.sh` script provides automated deployment of the Coach Ba software with proper user management, permissions, and file setup.

#### Prerequisites

Before running the deployment script, ensure the following packages are installed:

```bash
sudo apt install acl pwgen
```

#### Running the Deployment

Execute the deployment script with root privileges:

```bash
sudo -u root ./deploy.sh
```

#### What deploy.sh Does

The deployment script performs the following operations:

1. **Package Management**:
   - Automatically checks and installs required Linux packages (`pwgen`, `acl`)
   - Ensures all dependencies are met before proceeding

2. **User and Group Management**:
   - Creates a dedicated group `cb` for Coach Ba users
   - Creates default users (`cb1`, `cb2`) if they don't exist
   - Generates secure passwords using `pwgen` (12 characters, alphanumeric)
   - Adds users to the `cb` group for proper access control

3. **Directory Structure**:
   - Creates `/home/[user]/bin/` directories for each user
   - Creates `/opt/cb/` shared directory with proper group permissions
   - Sets up ACL (Access Control Lists) for enhanced security
   - Applies setgid bit for group inheritance

4. **File Deployment**:
   - Copies core Coach Ba files (`cbc.sh`, `cbl.sh`, `.env`) to user directories
   - Creates backup directories with timestamps before overwriting existing files
   - Sets appropriate file permissions (755 for scripts, 644 for configuration)
   - Automatically configures `.env` files with user-specific settings

5. **Security Configuration**:
   - Sets proper file ownership (user:cb group)
   - Applies restrictive permissions (770 for shared directories, 755 for user directories)
   - Configures default ACL permissions for new files
   - Stores user passwords securely and cleans up temporary files

#### Post-Deployment

After running the deployment script:

1. Switch to the deployed user:

   ```bash
   wsl -u [username]
   # or
   su - [username]
   ```

2. Verify the PATH includes the user's bin directory:

   ```bash
   echo $PATH | grep -wo "/home/[username]/bin"
   ```

3. Test the installation:

   ```bash
   cbc.sh
   ```

#### Configuration Files

- **Users**: Default users `cb1` and `cb2` (configurable via `cb_users` array)
- **Packages**: Core files `cbc.sh`, `cbl.sh`, `.env` (configurable via `cb_package` array)
- **Group**: All users are added to the `cb` group for shared access
- **Permissions**: Follows the principle of least privilege with group-based access control

1. Install Linux and run Bash:
   - Windows 10+

    ```console
    # Install WSL under Administrator
    wsl --install

    # Run Bash
    wsl
    # or
    bash
    ```

   - Linux

    ```bash
    # Run Bash
    bash
    ```

## Usage

- Start the Server

Run the server with the required options:

```bash
# Set environment variables
./.env

# Start the Server in coach mode, no time limitation
./cbs.sh -r > /dev/null &

# Start the Server in coach mode, 10 min limitation
./cbs.sh -r -l 10 > /dev/null &

# Start the Server for the specified user without output
./cbs.sh -u user -r > /dev/null 2>&1 &
```

- Start the Client

Run the client with the required options:

```bash
# Set environment variables
./.env

# Start the Server
cbc.sh
```

- **Client Commands**:
  - `s`: Start the session.
  - `t`: Show remaining time or test start time.
  - `l`: List all questions.
  - `p`: Show progress.
  - `number`: Request a specific question (e.g.: 1).
  - `a`: Submit an answer.
  - `r`: Mark a question for later.
  - `f`: Finish the session.
  - `q`: Quit the session.

---

### File Structure

- `cbc.sh`: Client script.
- `cbs.sh`: Server script.
- `cbl.sh`: Shared library for common functions.
- `deploy.sh`: This script provides automated deployment of the Client script.
- `courses/course.txt`: Contains questions and answers.
- `courses/course.des`: Contains course descriptions.
- `logs/`: Directory for log files.
- `results/`: Directory for user result files.

### Logging

- Log files are stored in the logs/ directory.
- Log file format: user_topic_application.log.
- Log entry format: Date-time|Logging level|Username|Topic|Message.
- Five verbosity levels:
  - `-v`: CRIT level.
  - `-vv`: ERR level.
  - `-vvv`: WARNING level.
  - `-vvvv`: INFO level.
  - `-vvvvv`: DEBUG level.

## Security

- Named pipes and files are readable and writable only by the owner and group.
- Environment variables (CB_USERNAME and CB_TOPIC) can be used as fallbacks for command-line options.

## License

This project is licensed under the [GNU General Public License 3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). See the LICENSE file for details.

## Authors

- Yakiv Koliada / ikclouds (ik - Nickname)

## Acknowledgments

Special thanks to the open-source community and commercial companies for providing great tools and inspiration for this project: `Linux`, `Bash`, `Visual Studio Code`, `WSL`, `GitHub Copilot`.
