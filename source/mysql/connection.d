module mysql.connection;

import mysql.binding;

public import mysql.resultset;
public import mysql.row;
import mysql.query_interface;

import std.stdio;
import std.exception;
import std.typecons;

class MysqlDatabaseException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Connection {
    private string _dbname;
    private MYSQL* mysql;
    private string lastErrorMsg;

    this(string host, string user, string pass, string db) {
        initMysql();
        connect(host, 0, user, pass, db, null);
    }

    this(string host, uint port, string user, string pass, string db) {
        initMysql();
        connect(host, port, user, pass, db, null);
    }

    this(string host, string user, string pass) {
        initMysql();
        connect(host, user, pass);
    }

    this() {
        initMysql();
    }

    private void initMysql () {
        mysql = enforceEx!(MysqlDatabaseException)(mysql_init(null), "Couldn't init mysql");
        setReconnect(true);
    }

    void connect(string host, uint port, string user, string pass, string db, string unixSocket) {
        enforceEx!(MysqlDatabaseException)(
            mysql_real_connect(mysql,
                toCstring(host),
                toCstring(user),
                toCstring(pass),
                toCstring(db),
                port,
                unixSocket ? toCstring(unixSocket) : null,
                0),
            error()
        );

        _dbname = db;

        // we want UTF8 for everything
        query("SET NAMES 'utf8'");
    }

    void connect(string host, uint port, string user, string pass, string db) {
        connect(host, port, user, pass, db, null);
    }

    void connect(string host, string user, string pass, string db) {
        connect(host, 0, user, pass, db, null);
    }

    void connect(string host, string user, string pass) {
        connect(host, 0, user, pass, null, null);
    }

    int selectDb(string newDbName) {
        auto res = mysql_select_db(mysql, toCstring(newDbName));
        _dbname = newDbName;
        return res;
    }

    string dbname() {
        return _dbname;
    }

    int setOption(mysql_option option, const void* value) {
        return mysql_options(mysql, option, &value);
    }

    int setReconnect(bool value) {
        return setOption(mysql_option.MYSQL_OPT_RECONNECT, &value);
    }

    int setConnectTimeout(int value) {
        return setOption(mysql_option.MYSQL_OPT_CONNECT_TIMEOUT, cast(const(char*))value);
    }

    static ulong clientVersion() {
        return mysql_get_client_version();
    }

    static string clientVersionString() {
        return fromCstring(mysql_get_client_info());
    }

    void startTransaction() {
        query("START TRANSACTION");
    }

    void commit() {
        query("COMMIT");
    }

    void rollback() {
        query("ROLLBACK");
    }

    string error() {
        return fromCstring(mysql_error(mysql));
    }

    void close() {
        if (mysql) {
            mysql_close(mysql);
            mysql = null;
        }
    }

    ~this() {
        close();
    }

    // MYSQL API call
    int lastInsertId() {
        return cast(int) mysql_insert_id(mysql);
    }

    // MYSQL API call
    int affectedRows() {
        return cast(int) mysql_affected_rows(mysql);
    }

    // MYSQL API call
    string escape(string str) {
        ubyte[] buffer = new ubyte[str.length * 2 + 1];
        buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, cast(uint) str.length);

        return cast(string) buffer;
    }

    // MYSQL API call
    Rows queryImpl(string sql) {
        enforceEx!(MysqlDatabaseException)(
            !mysql_query(mysql, toCstring(sql)),
        error() ~ " :::: " ~ sql);

        return new ResultSet(mysql_store_result(mysql), sql).toAA();
    }

    // To be used with commands that do not return a result (INSERT, UPDATE, etc...)
    bool execImpl(string sql) {
        bool success = false;

        if (mysql_query(mysql, toCstring(sql)) == 0) {
            success = true;
            this.lastErrorMsg = "";
        } else {
            this.lastErrorMsg = error() ~ " :::: " ~ sql;
            throw new MysqlDatabaseException(this.lastErrorMsg);
        }

        return success;
    }

    // MYSQL API call
    int ping() {
        return mysql_ping(mysql);
    }

    // MYSQL API call
    string stat() {
        return fromCstring(mysql_stat(mysql));
    }

    // ====== helpers ======

    // Smart interface thing.
    // accept multiple attributes and make replacement of '?' in sql
    // like this:
    // auto row = mysql.query("select * from table where id = ?", 10);
    Rows query(T...)(string sql, T t) {
        return queryImpl(QueryInterface.makeQuery(this, sql, t));
    }

    bool exec(T...)(string sql, T t) {
        return execImpl(QueryInterface.makeQuery(this, sql, t));
    }

    string dbErrorMsg() {
        return this.lastErrorMsg;
    }

    // simply make mysq.query().front
    // and if no rows then raise an exception
    Nullable!MysqlRow queryOneRow(string file = __FILE__, size_t line = __LINE__, T...)(string sql, T t) {
        auto res = query(sql, t);
        if (res.empty) {
            return Nullable!MysqlRow.init;
        }
        auto row = res.front;

        return Nullable!MysqlRow(row);
    }
}

class EmptyResultException : Exception {
    this(string message, string file = __FILE__, size_t line = __LINE__) {
        super(message, file, line);
    }
}