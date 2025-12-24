
const fs = require('fs');
const path = require('path');

const filesToRefactor = [
    { impactory: '-impactory.firebaserc', original: '.firebaserc' },
    { impactory: '.eslintrc-impactory.cjs', original: '.eslintrc.cjs' },
    { impactory: 'MissionList-impactory.tsx', original: 'MissionList.tsx' },
    { impactory: 'README-impactory.md', original: 'README.md' },
    { impactory: 'SessionManager-impactory.tsx', original: 'SessionManager.tsx' },
    { impactory: 'SiteStats-impactory.tsx', original: 'SiteStats.tsx' },
    { impactory: 'src/firebase/admin-init-impactory.ts', original: 'src/firebase/admin-init.ts' },
    { impactory: 'src/firebase/client-init-impactory.ts', original: 'src/firebase/client-init.ts' },
    { impactory: 'src/firebase/auth/getCurrentUserServer-impactory.ts', original: 'src/firebase/auth/getCurrentUserServer.ts' },
    { impactory: 'src/firebase/auth/getUserRoleServer-impactory.ts', original: 'src/firebase/auth/getUserRoleServer.ts' },
    { impactory: 'src/firebase/firestore/queries-impactory.ts', original: 'src/firebase/firestore/queries.ts' },
    { impactory: 'src/types/FeedbackForm-impactory.tsx', original: 'src/types/FeedbackForm.tsx' },
    { impactory: 'src/types/page-impactory.tsx', original: 'src/types/page.tsx' },
    { impactory: 'src/types/user-impactory.ts', original: 'src/types/user.ts' },
    { impactory: 'app/[locale]/layout-impactory.tsx', original: 'app/[locale]/layout.tsx' }
];

filesToRefactor.forEach(file => {
    const impactoryPath = path.join(__dirname, file.impactory);
    const originalPath = path.join(__dirname, file.original);

    if (fs.existsSync(impactoryPath)) {
        fs.renameSync(impactoryPath, originalPath);
        console.log(`Successfully renamed ${file.impactory} to ${file.original}`);
    } else {
        console.log(`${file.impactory} not found.`);
    }
});
