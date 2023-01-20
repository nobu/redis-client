# frozen_string_literal: true

require "mkmf"

if RUBY_ENGINE == "ruby" && !RUBY_PLATFORM.match?(/mswin/)
  have_func("rb_hash_new_capa", "ruby.h")

  hiredis_dir = File.expand_path('vendor', __dir__)

  make_program = with_config("make-prog", ENV["MAKE"])
  make_program ||= case RUBY_PLATFORM
  when /(bsd|solaris)/
    'gmake'
  else
    'make'
  end

  openssl_include, openssl_lib = dir_config("openssl")

  openssl_include ||= dir_config("opt").first
    &.split(File::PATH_SEPARATOR)
    &.detect { |dir| dir.include?("openssl") }

  openssl_lib ||= dir_config("opt").last
    &.split(File::PATH_SEPARATOR)
    &.detect { |dir| dir.include?("openssl") }

  if (!openssl_include || !openssl_lib) && !have_header("openssl/ssl.h")
    raise "OpenSSL library could not be found. You might want to use --with-openssl-dir=<dir> option to specify the " \
      "prefix where OpenSSL is installed."
  end

  Dir.chdir(hiredis_dir) do
    flags = ["static", "USE_SSL=1"]
    if openssl_lib
      flags << %(CFLAGS="-I#{openssl_include}") << %(SSL_LDFLAGS="-L#{openssl_lib}")
    end

    flags << "OPTIMIZATION=-g" if ENV["EXT_PEDANTIC"]

    unless system(make_program, *flags)
      raise "Building hiredis failed"
    end
  end

  $CFLAGS << " -I#{hiredis_dir}"
  $LDFLAGS << " -lssl -lcrypto"
  $libs << " #{hiredis_dir}/libhiredis.a #{hiredis_dir}/libhiredis_ssl.a "
  $CFLAGS << " -std=c99 "
  if ENV["EXT_PEDANTIC"]
    $CFLAGS << " -Werror"
    $CFLAGS << " -g "
  else
    $CFLAGS << " -O3 "
  end

  append_cflags "-fvisibility=hidden"

  $CFLAGS << " -Wno-declaration-after-statement" # Older compilers
  $CFLAGS << " -Wno-compound-token-split-by-macro" # Older rubies on macos

  create_makefile("redis_client/hiredis_connection")
else
  File.write("Makefile", dummy_makefile($srcdir).join)
end
