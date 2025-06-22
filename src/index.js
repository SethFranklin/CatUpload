
import express from 'express';
import fs from 'fs';
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

if (localDeploy) {
  app.use(express.static('static'));
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
  }
  res.json(await catDB.insertCat(req.body.name, req.body.age, imageFileName));
});

app.listen(port, () => {
  console.log(`CatUpload server listening on port ${port}`);
});
