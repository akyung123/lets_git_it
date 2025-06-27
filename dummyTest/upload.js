const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');
const dummyData = JSON.parse(fs.readFileSync('dummydata.json', 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadData() {
  for (const [collectionName, documents] of Object.entries(dummyData)) {
    const collectionRef = db.collection(collectionName); // 동적으로 컬렉션 생성

    for (const [docId, docData] of Object.entries(documents)) {
      await collectionRef.doc(docId).set(docData);
      console.log(`Uploaded to /${collectionName}/${docId}`);
    }
  }

  console.log('All data uploaded!');
}

uploadData();
