vim9script

import './infra.vim' as infra

infra.SetupTestFile()

execute 'e ' .. infra.test_file
execute 'PagerInit'
