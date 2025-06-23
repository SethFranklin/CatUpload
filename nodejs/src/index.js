
import express from 'express';
import cors from "cors";
import fs from 'fs';
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { randomBytes } from 'crypto';
import 'dotenv/config';
import { CatDB } from "./db.js";

const localDeploy = (process.env.LOCAL_DEPLOY === 'true');

const catDB = new CatDB();
await catDB.initialize();

const app = express();
const port = parseInt(process.env.PORT);

app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cors());

let s3Client;

if (localDeploy) {
  app.use(express.static('static'));
} else {
  s3Client = new S3Client({ region: process.env.AWS_REGION });
}

app.get('/api/cats', async (req, res) => {
  res.json(await catDB.getCats());
});

app.post('/api/cats', async (req, res) => {
  const base64Image = req.body.image.replace(/^data:image\/png;base64,/, '');
  const imageFileName = randomBytes(16 / 2).toString('hex') + '.png';
  if (localDeploy) {
    // write to filesystem
    fs.writeFileSync('./static/cats/' + imageFileName, base64Image, 'base64');
  } else {
    // write to s3
    const input = {
      Body: Buffer.from(base64Image, "base64"),
      ContentEncoding: 'base64',
      ContentType: 'image/png',
      Bucket: process.env.AWS_S3_BUCKET_NAME,
      Key: "cats/" + imageFileName
    };
    const command = new PutObjectCommand(input);
    const response = await s3Client.send(command);
  }
  res.json(await catDB.insertCat(req.body.name, req.body.age, imageFileName));
});

app.listen(port, () => {
  console.log(`CatUpload server listening on port ${port}`);
});
