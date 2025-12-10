# Scholesa Platform

This is the repository for the Scholesa Platform, an Education 2.0 operating system for K-9 learning studios and schools.

## Getting Started

### Prerequisites

- Node.js (v18 or later)
- npm, yarn, or pnpm
- Firebase CLI

### Installation

1.  Install root dependencies:

    ```bash
    npm install
    ```

2.  Install Firebase Functions dependencies:

    ```bash
    cd functions && npm install && cd ..
    ```

### Running the Development Server

```bash
npm run dev
```

### Running the Firebase Emulators

```bash
firebase emulators:start
```

### Building for Production

```bash
npm run build
```

### Deployment

To deploy the application to Firebase:

```bash
firebase deploy
```

To deploy only the Firebase Functions:

```bash
cd functions
npm run build
firebase deploy --only functions
```
