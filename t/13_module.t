use strict;
use warnings;

use Data::Dumper;
use Ref::Util qw/ is_scalarref /;
use Test::More;
use JavaScript::Duktape::XS;

sub _module_resolve {
    my ($module_id, $parent_id) = @_;

    my $resolved = sprintf("%s.js", $module_id);
    # printf STDERR ("resolve_cb id='%s', parent-id='%s', resolve-to='%s'\n", $module_id, $parent_id, $resolved);
    return $resolved;

}

sub _module_load {
    my ($module_id, $exports, $module, $filename) = @_;

    # printf STDERR ("load_cb id='%s', filename='%s'\n", $module_id, $filename);

    my $source;
    if ($module_id eq 'pig.js') {
        $source = sprintf("module.exports = 'you\\'re about to get eaten by %s';", $module_id);
    }
    elsif ($module_id eq 'cow.js') {
        $source = "module.exports = require('pig');";
    }
    elsif ($module_id eq 'ape.js') {
        $source = "module.exports = { module: module, __filename: __filename, wasLoaded: module.loaded };";
    }
    elsif ($module_id eq 'badger.js') {
        $source = "exports.foo = 123; exports.bar = 234;";
    }
    elsif ($module_id eq 'comment.js') {
        $source = "exports.foo = 123; exports.bar = 234; // comment";
    }
    elsif ($module_id eq 'shebang.js') {
        $source = "#!ignored\nexports.foo = 123; exports.bar = 234;";
    # } else {
    #     (void) duk_type_error(ctx, "cannot find module: %s", module_id);
    }

    return $source;
}

sub test_module {
    my $duk = JavaScript::Duktape::XS->new();
    $duk->set('perl_module_resolve', \&_module_resolve);
    $duk->set('perl_module_load', \&_module_load);
    ok($duk, "created JavaScript::Duktape::XS object");

    $duk->eval('var p = require("pig");');
    is($duk->typeof('p'), 'string', 'basic require()');

    $duk->eval('var r = require("cow"); var c = r.indexOf("pig");');
    # printf STDERR ("cow: %s", Dumper($duk->get('r')));
    ok($duk->get('c') >= 0, 'nested require()');

    $duk->eval('var ape1 = require("ape"); var ape2 = require("ape");');
    my $a1 = $duk->get('ape1');
    my $a2 = $duk->get('ape2');
    is_deeply($a1, $a2, 'cached require');

    $duk->eval('var ape1 = require("ape"); var inCache = "ape.js" in require.cache; delete require.cache["ape.js"]; var ape2 = require("ape");');
    ok($duk->get('inCache'), 'cached required, inCache');
    ok($duk->get('ape2') ne $duk->get('ape1'), 'cached require, not equal');

    $duk->eval('var ape3 = require("ape");');

    # This will not work because typeof will never return function
    # ./test 'var ape = require("ape"); assert(typeof ape.module.require === "function", "module.require()");'
    # is($duk->typeof('ape3.module.require'), "function", "module.require()");
    $duk->eval('var ape_type = typeof ape3.module.require');
    is($duk->get('ape_type'), "function", "module.require is a function");

    my $a30 = $duk->get('ape3');
    my $a31 = $duk->get('ape3.module.exports');
    my $a32 = $duk->get('ape3.module.id');
    my $a33 = $duk->get('ape3.module.filename');
    my $a34 = $duk->get('ape3.module.loaded');
    my $a35 = $duk->get('ape3.wasLoaded');
    my $a36 = $duk->get('ape3.__filename');

    is_deeply($a30, $a31, 'aped require');

    is($a32, 'ape.js', 'ape module id');

    is($a32, $a33, 'ape module filename');

    ok( $a34, 'module loaded');
    ok(!$a35, 'wasLoaded');

    is($a36, 'ape.js', 'ape __filename');

    $duk->eval('var badger = require("badger");');
    # printf STDERR ("badger: %s", Dumper($duk->get('badger')));
    is($duk->get('badger.foo'), 123, 'exports.foo assignment');
    is($duk->get('badger.bar'), 234, 'exports.bar assignment');

    $duk->eval('var comment = require("comment");');
    # printf STDERR ("comment %s", Dumper($duk->get('comment')));
    is($duk->get('comment.foo'), 123, 'comment.foo, last line with // comment');
    is($duk->get('comment.bar'), 234, 'comment.bar, last line with // comment');

    $duk->eval('var shebang = require("shebang");');
    is($duk->get('shebang.foo'), 123, 'shebang.foo');
    is($duk->get('shebang.bar'), 234, 'shebang.bar');
}

sub main {
    test_module();
    done_testing;

    return 0;
}

exit main();
