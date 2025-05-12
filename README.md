# Coach Ba

## Overview

The **Coach Ba** software is a Bash-based testing environment that allows users to take tests on various topics. It consists of three main components:

- **Client (`cbc.sh`)**: A script that interacts with the user, sends commands to the server, and displays results.
- **Server (`cbs.sh`)**: A script that manages the test session, processes user commands, validates answers, and calculates results.
- **Library (`cbl.sh`)**: A Library of common functions for client and server.

The project is designed to be modular, secure, and extensible, with all questions, answers, and user results stored in separate files.

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

- Commands:
  - `s`: Start the test session.
  - `t`: Display the remaining time or test start time.
  - `l`: List all questions.
  - `p`: Display progress (answered and marked questions).
  - `number`: Request a specific question by its number.
  - `a`: Submit an answer.
  - `r`: Mark a question for answering later.
  - `f`: Finish the session and calculate results.
  - `q`: Quit the session.
- Displays test start time and progress.
- Handles user input and sends commands to the server.

### Server (`cbs.sh`)

- Manages test sessions and validates answers.
- Supports time-limited and non-time-limited modes.
- Calculates the final result as a percentage of correct answers.
- Stores user results in a file with the format: `user_topic_yyyymmdd_hhmm`.
- Provides immediate feedback on answers or final results at the end of the session.
- Handles unexpected scenarios, such as missing files or crashes.

## Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/your-repo/coach_bash.git
    cd coach_bash
    ```

2. Set up the environment:
   - Create a .env file to define default values for CB_USERNAME and CB_TOPIC:

   ```bash
   export CB_USERNAME=user
   export CB_TOPIC=PLLB10001001
   ```

3. Ensure the required files are available:
    - `courses/course.txt`: Contains questions and answers.
    - `courses/course.des`: Contains course descriptions.

4. Set executable permissions for the scripts:

   ```bash
   chmod +x cbc.sh cbs.sh
   ```

5. Install Linux and run Bash:
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

# Start the Server, no time limitation
./cbs.sh -r > /dev/null &

# Start the Server, 10 min limitation
./cbs.sh -r -t 10 > /dev/null &
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
