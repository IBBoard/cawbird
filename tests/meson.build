
tests = [
  'avatarcache',
  'avatardownload',
  'bundlehistory',
  'dmmanager',
  'filters',
  'friends',
  'inlinemediadownloader',
  'texttransform',
  'tweetmodel',
  'tweetparsing',
  'twitteritem',
  'usercompletionmodel',
  'usercounter',
  'utils',
]

foreach test_name : tests
  testcase = executable(
    test_name,
    test_name + '.vala',
    meson.source_root() + '/vapi/cawbird-internal.vapi',
    cb_resources,
    dependencies: cb_dep,
    vala_args: [
      '--gresources=' + meson.source_root() + '/cawbird.gresource.xml',
    ],
  )
  test(test_name, testcase)
endforeach
