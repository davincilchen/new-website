'use strict'

require! {
  fs
  path
  jade
  mkdirp
  Generator: \./Generator
  config: \../../config.json
}

script = {}

script.main = !->
  console.log!
  @init !->
    console.log '  執行'
    console.log!
    @generateAll!

script.init = (cb) !->
  console.log '  初始化'

  @initProcessEvent!

  @basedir =  path.join __dirname, \../..
  @generator = Generator.create!
  @enum = @getTypes!
  @types = @cleanTypes process.argv.slice 2
  @list = []

  if !@types.length
    @types = @enum.slice!

  @generator.on \stream, @~onStream

  _mkdir = @~mkdir
  cb = cb.bind @

  <- @loadTemplates
  <- _mkdir
  cb!

script.getTypes = ->
  Object.keys config.generator || {}

script.cleanTypes = (types) ->
  newArr = []
  e = @enum
  types.forEach (type) !->
    if !!~indexOf type
      newArr.push type
  newArr

script.loadTemplates = (cb) !->
  len = @types.length
  templates = @templates = {}
  @types.forEach (type) !->
    file = config.generator[type].template
    if file
      fs.readFile file, (err, content) !->
        if !err
          templates[type] = content
        if !--len
          cb!
    else
      len--

script.mkdir = (cb) !->
  len = @types.length
  exit = @~exit
  @types.forEach (type) !->
    des = config.generator[type].destination
    if des
      mkdirp des, (err) !->
        if err
          exit err
        if !--len
          cb!
    else
      len--

script.generateAll = !->
  @types.forEach @~generate

script.generate = (type) !->
  pattern = path.join @basedir, config.generator[type].source
  @generator.generate pattern, {type: type}

script.onStream = (stream) !->
  console.log "    開始: #{stream.data.file}"

  meta = stream.meta
  template = @templates[stream.data.type] || ''
  type = config.generator[stream.data.type]
  addToList = @~addToList;

  source = type.source.split('*');

  srcdir = path.join @basedir, source[0]
  desdir = path.join @basedir, type.destination
  if srcdir[srcdir.length - 1] == path.sep
    srcdir = srcdir.substr 0, srcdir.length - 1
  filepath = stream.data.file.replace(srcdir, desdir).replace(/\.md$/, '.html')

  failed = (err) !->
    console.log "    失敗: #{filepath}. (#{err.message})"

  stream.on \readable, !->
    var data
    content = ''
    while data = @.read()
      content += data

    if !content
      return

    meta.content = content
    html = jade.render template, {article: meta, filename: path.join __dirname, \../../templates/template.jade}

    mkdirp path.dirname(filepath), (err) !->
      if err
        failed err
      else
        fs.writeFile filepath, html, (err) !->
          if err
            failed err
          else
            console.log "    成功: #{filepath}"
            addToList stream.data.type, meta.date, meta.title, filepath

script.addToList = (type, date, title, file) !->
  isIndex = /index\.html/;

  if !isIndex.test file

    @list.push {
      type: type
      title: title
      file: file
      date: date || new Date()
    }

script.initProcessEvent = !->
  process.on \exit, @~onProcessExists

script.onProcessExists = (code) !->
  if !code
    console.log!
    console.log '  建立列表'
    console.log!
    @list.sort @listSort
    data = @listCategorize!
    data = JSON.stringify data
    listFile = path.join process.cwd!, \public/list.json 
    console.log '    ' + listFile
    fs.writeFileSync listFile, data
  console.log!

script.listSort = (a, b) ->
  a.date - b.date

script.listCategorize = ->
  categories = {}

  @types.forEach (type) !->
    categories[type] = []

  @list.forEach (article) !->
    categories[article.type].push article

  categories

script.exit = (err) !->
  if err
    console.log "Error: #{err.message}"
    process.exit 1
  else
    process.exit 0

script.main!
