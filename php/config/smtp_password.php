<?php
// smtp_password.php

// Prevent direct web access: if this file is requested directly, deny access.
// When included from another script (e.g. contact.php), SCRIPT_FILENAME will point
// to the including script, so the check below will not trigger.
if (php_sapi_name() !== 'cli' && basename($_SERVER['SCRIPT_FILENAME']) === basename(__FILE__)) {
    http_response_code(403);
    exit('Forbidden');
}

// Return the SMTP password
return 'W4ll_4rt_3ma1l!';