# Coach Ba

## Overview

The **Coach Ba** software is a Bash-based testing environment that allows users to take tests on various topics. It consists of three main components:

- **Client (`cbc.sh`)**: A script that interacts with the user, sends commands to the server, and displays results.
- **Server (`cbs.sh`)**: A script that manages the test session, processes user commands, validates answers, and calculates results.
- **Library (`cbl.sh`)**: A Library of common functions for client and server.

The project is designed to be modular, secure, and extensible, with all questions, answers, and user results stored in separate files.

---

## Licensing

The `Coach Ba` software is published under the [GNU General Public License 3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)

---

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

---

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-repo/coach_bash.git
   cd coach_bash
   ```

## Run

1. Run **Server (`cbs.sh`)**:

    ```bash
    . ./.env            # set environment variables
    ./cbs.sh -r         # run server in response mode
    ```

2. Run **Client (`cbc.sh`)**:

    ```bash
    . ./.env            # set environment variables
    ./cbc.sh            # run client
    ```
