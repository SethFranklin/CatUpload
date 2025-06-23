import 'dotenv/config';
import oracledb from "oracledb";

const createCatTableStatement = `
	create table cats (
		cat_id number primary key,
		created_timestamp number,
		name varchar(64),
		age number,
		imageFileName varchar(512)
	)
`;

const insertCatStatement = `
	insert into cats values (
		:cat_id,
		:created_timestamp,
		:name,
		:age,
		:imageFileName
	)
`;

const selectNewCatIdStatement = `
	select max(cat_id)+1 as cat_id from cats
`;

const selectCatsStatement = `
	select * from cats order by created_timestamp desc
`;

class CatDB {

	constructor() {
	}

	async initialize() {
		this.connection = await oracledb.getConnection({
			user          : process.env.ORACLE_USER,
			password      : process.env.ORACLE_PASSWORD,
			connectString : process.env.ORACLE_CONNECT_STRING
		});

		try {
			await this.connection.execute(createCatTableStatement);
		} catch (e) {
		}
	}

	async insertCat(name, age, imageFileName) {
		let query_result = await this.connection.execute(selectNewCatIdStatement);
		const cat_id = query_result.rows[0][0] ?? 0;

		query_result = await this.connection.execute(insertCatStatement, [
			cat_id,
			Date.now(),
			name,
			age,
			imageFileName
		]);

		await this.connection.commit();

		return cat_id;
	}

	async getCats() {
		const query_result = await this.connection.execute(selectCatsStatement);
		return query_result.rows;
	}

}

export { CatDB };