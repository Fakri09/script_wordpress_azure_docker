<?php
/** Enable W3 Total Cache */
define('WP_CACHE', true); // Added by W3 Total Cache


/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

//Using environment variables for memory limits
$wp_memory_limit = (getenv('WP_MEMORY_LIMIT') && preg_match("/^[0-9]+M$/", getenv('WP_MEMORY_LIMIT'))) ? getenv('WP_MEMORY_LIMIT') : '128M';
$wp_max_memory_limit = (getenv('WP_MAX_MEMORY_LIMIT') && preg_match("/^[0-9]+M$/", getenv('WP_MAX_MEMORY_LIMIT'))) ? getenv('WP_MAX_MEMORY_LIMIT') : '256M';

/** General WordPress memory limit for PHP scripts*/
define('WP_MEMORY_LIMIT', $wp_memory_limit );

/** WordPress memory limit for Admin panel scripts */
define('WP_MAX_MEMORY_LIMIT', $wp_max_memory_limit );


//Using environment variables for DB connection information

// ** Database settings - You can get this info from your web host ** //
$connectstr_dbhost = getenv('DATABASE_HOST');
$connectstr_dbname = getenv('DATABASE_NAME');
$connectstr_dbusername = getenv('DATABASE_USERNAME');
$connectstr_dbpassword = getenv('DATABASE_PASSWORD');

// Using managed identity to fetch MySQL access token
if (strtolower(getenv('ENABLE_MYSQL_MANAGED_IDENTITY')) === 'true') {
        try {
                require_once(ABSPATH . 'class_entra_database_token_utility.php');
                if (strtolower(getenv('CACHE_MYSQL_ACCESS_TOKEN')) !== 'true') {
                        $connectstr_dbpassword = EntraID_Database_Token_Utilities::getAccessToken();
                } else {
                        $connectstr_dbpassword = EntraID_Database_Token_Utilities::getOrUpdateAccessTokenFromCache();
                }
        } catch (Exception $e) {
                // An empty string displays a 502 HTTP error page rather than a database connection error page. So, using a dummy string instead.
                $connectstr_dbpassword = '<dummy-value>';
                error_log($e->getMessage());
        }
}

/** The name of the database for WordPress */
define('DB_NAME', $connectstr_dbname);

/** MySQL database username */
define('DB_USER', $connectstr_dbusername);

/** MySQL database password */
define('DB_PASSWORD',$connectstr_dbpassword);

/** MySQL hostname */
define('DB_HOST', $connectstr_dbhost);

/** Database Charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The Database Collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/** Enabling support for connecting external MYSQL over SSL*/
$mysql_sslconnect = (getenv('DB_SSL_CONNECTION')) ? getenv('DB_SSL_CONNECTION') : 'true';
if (strtolower($mysql_sslconnect) != 'false' && !is_numeric(strpos($connectstr_dbhost, "127.0.0.1")) && !is_numeric(strpos(strtolower($connectstr_dbhost), "localhost"))) {
        define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
}


/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',         'Q!y hsb_?KK+!Rlv? 5a,5jK&r&$9]~U(GSQ8aNcH)c8G(-.|O3###7sQQ=H1}[A' );
define( 'SECURE_AUTH_KEY',  'h4`C*EtzXn!_Dl>0*h{U;+w}`nNYJPN9+:&6[oa!=/|tEet8$qaq+*}YFNwW`rRN' );
define( 'LOGGED_IN_KEY',    ',v6a~uaKpA5>CtYN%GemxjA +4OC&$=2:Ut!JMiD!y<kR|(R^8(~MRJjA$zZA7UG' );
define( 'NONCE_KEY',        'Zi1z&!8xm,c+eMN0pX,oy4@xfZ/mq|4)97Ms#6=E4~mA7mdZzvYUev1mRmt.l<YA' );
define( 'AUTH_SALT',        ';JSml~_pZ_g}PES$%]rQnRg`lR>A_AjqE=@z,dS(Za/VU{lO;U.|=F:V}0`~/Pt$' );
define( 'SECURE_AUTH_SALT', 'lw+ZgO<<r-Q%vO;f/1#r/~f5Zoqt)u{Efw#p`pP<5^mLKH;%6sC~:sBW_{@9K6.y' );
define( 'LOGGED_IN_SALT',   'Kx5[XCqb1*A6oPYN;6Rxb@>-=mMHPJfE@A0jfGsH2~aYUuvhksQ-CcSb5m)2;<nq' );
define( 'NONCE_SALT',       '6fxk{N]rKY}iZR(96@V2[&mhH(Dt5(?jw<@SS;y)(W8hDU6T9#`+[}B*x>55n0!q' );

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );

/* That's all, stop editing! Happy blogging. */
/**https://developer.wordpress.org/reference/functions/is_ssl/ */
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')
        $_SERVER['HTTPS'] = 'on';

$http_protocol='http://';
if (!preg_match("/^localhost(:[0-9])*/", $_SERVER['HTTP_HOST']) && !preg_match("/^127\.0\.0\.1(:[0-9])*/", $_SERVER['HTTP_HOST'])) {
        $http_protocol='https://';
}

//Relative URLs for swapping across app service deployment slots
define('WP_HOME', $http_protocol . $_SERVER['HTTP_HOST']);
define('WP_SITEURL', $http_protocol . $_SERVER['HTTP_HOST']);
define('WP_CONTENT_URL', '/wp-content');
define('DOMAIN_CURRENT_SITE', $_SERVER['HTTP_HOST']);

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
