# Mysqlclientd

Documentation is not ready yet

```D
import std.stdio;
import mysql;

void main() {
    auto conn = new Connection("localhost", 3306, "root", "root", "mysql_d_testing");

    conn.query("DROP TABLE IF EXISTS users");
    conn.query("CREATE TABLE users (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        sex tinyint(1) DEFAULT NULL,
        birthdate DATE,
        PRIMARY KEY (id)
    );");

    conn.query("insert into users (name, sex, birthdate) values (?, ?, ?);", "Paul", 1, "1981-05-06");
    conn.query("insert into users (name, sex, birthdate) values (?, ?, ?);", "Anna", 0, "1983-02-13");

    auto rows = conn.query("select * from users");

    rows.length; // => 2
    foreach (user; rows) {
        writefln("User %s, %s, born on %s", user["name"], user["sex"] == "1" ? "male" : "female", user["birthdate"]);
    }

    bool result = conn.exec("select name, gender from users");
    if (!result) {
      writefln("SQL Error: %s", conn.dbErrorMsg);
    }
}
```

Output is:
```
User Paul, male, born on 1981-05-06
User Anna, female, born on 1983-02-13
```

**Escaping**

    ? - convert to string with escaped quotes to prevent sql injection
    `?` - convert to string but without quotes

```d
conn.query("DROP TABLE ?", "table_name"); // error
// SQL error near near ''table_name'' at line 1 :::: DROP TABLE 'table_name'
// should be `some_table` not 'some_table'

conn.query("DROP TABLE `?`", "table_name"); // working
```
