const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');
const dummyData = JSON.parse(fs.readFileSync('dummydata.json', 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://elderly-care-project-464204-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function uploadData() {
  try {
    // 루트에 전체 데이터 덮어쓰기
    await db.ref('/').set(dummyData);
    console.log('Upload to Realtime Database complete!');
  } catch (error) {
    console.error('Upload failed:', error);
  }
}

uploadData();
