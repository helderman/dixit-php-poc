# dixit-php-poc

Under construction.

To test, prepare a local Linux environment as follows:

1. Install Apache webserver,
   then create a link from the html folder to this git repo:
   ```
   sudo ln -s $PWD/src /var/www/html/dixit
   ```
2. Install MySQL,
   create a new database named `dixit` (or whatever you find more convenient)
   and run the SQL script:
   ```
   sudo mysql dixit < sql/dixit.sql
   ```
3. Put a file `dbconn.php` in repo's parent folder
   with the following content:
   ```
   <?php
   $sSqlSrv = "127.0.0.1";
   $sSqlUid = "xxxxxxxx";
   $sSqlPwd = "xxxxxxxx";
   $sSqlDb  = "dixit";
   ?>
   ```

Now you should be ready to open the following URL in your web browser:
http://localhost/dixit/?game=1
