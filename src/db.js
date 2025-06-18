import 'dotenv/config';
import pg from 'pg';
const { Pool } = pg;

const createCatTableStatement = `
	create table if not exists cat (
		cat_id integer primary key,
        created_timestamp bigint,
		name varchar(64),
		age integer,
        image varchar(512)
	);
`;

const insertCatStatement = `
	insert into cat values (
		$1,
        $2,
        $3,
        $4,
        $5
	) on conflict (cat_id) do nothing;
`;

const selectNewCatIdStatement = `
	select max(cat_id)+1 as cat_id from cat;
`;

const selectCatsStatement = `
	select * from cat order by created_timestamp desc;
`;

class CatDB {

	constructor() {
	}

	generatePreview(body) {
		return body.substring(0, 20) + "...";
	}

	async initialize() {
        console.log(process.env.DATABASE_URL);

		const pool = new Pool({
			connectionString: process.env.DATABASE_URL,
		});

		this.client = await pool.connect();

		await this.client.query(createCatTableStatement);

	}

	async insertCat(name, age, image) {
		let query_res = await this.client.query(selectNewCatIdStatement);
		const cat_id = query_res.rows[0].cat_id ?? 0;

		query_res = await this.client.query(insertCatStatement, [
			cat_id,
			Date.now(),
            name,
            age,
            image
		]);

		return cat_id;
	}

	async getCats() {
		const query_res = await this.client.query(selectCatsStatement);
		return query_res.rows;
	}

}

export { CatDB };