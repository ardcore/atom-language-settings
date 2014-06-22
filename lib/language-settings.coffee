# coffeelint: disable=max_line_length
fs = require 'fs'
{allowUnsafeEval} = require 'loophole'
cson = allowUnsafeEval -> require 'cson'
_ = require 'underscore'
jsesc = require 'jsesc'

module.exports =

  activate: (state) ->
    @grammarDir = atom.getConfigDirPath() + "/language-settings/"
    @currentConfig = @grammarDir + ".current.cson"
    @baseConfig = atom.config.configFilePath

    atom.workspaceView.command "language-settings-edit:current", => @editCurrent()

    atom.syntax.on "grammar-added", (grammar) =>
      @addGrammarMenuItem grammar.name

    atom.workspaceView.on "application:open-your-config", => @restore()
    atom.workspaceView.on "application:show-settings", => @restore()
    atom.workspaceView.on "settings-view:open", => @restore()

    atom.project.registerOpener (uri) =>
      if (uri == 'atom://config')
        atom.config.configFilePath = @baseConfig
        baseJson = cson.parseFileSync @baseConfig
        defaults = _.clone(atom.config.defaultSettings.editor)
        baseJson = _.extend(defaults, baseJson.editor)
        for key, value of baseJson
          atom.config.set "editor." + key, value
        atom.project.openers[0](uri) # FIXME: hack

    if not fs.existsSync @grammarDir
      fs.mkdirSync(@grammarDir)

    if not fs.existsSync @currentConfig
      fs.writeFileSync(@currentConfig, '')

    atom.workspaceView.on "pane-container:active-pane-item-changed", => @updateGrammarConfig()
    atom.workspaceView.on "editor:grammar-changed", => @updateGrammarConfig()

  restore: ->
    atom.config.configFilePath = @baseConfig

  updateGrammarConfig: ->
    grammar = atom.workspace.getActiveEditor()?.getGrammar()

    if grammar
      filename = @grammarDir + @_normalize(grammar.name) + ".cson"

    if fs.existsSync filename
      @mixConfig @baseConfig, filename, @currentConfig
      atom.config.configFilePath = @currentConfig
      atom.config.load()
      atom.config.configFilePath = @baseConfig
    else
      atom.config.configFilePath = @baseConfig
      atom.config.load()

  addGrammarMenuItem: (grammar) ->
    atom.menu.add [
      {
        'label': 'Packages'
        'submenu': [
          'label': 'Language settings'
          'submenu': [
            { 'label': grammar, 'command': 'language-settings-edit: ' + @_normalize(grammar) }
          ]
        ]
      }
    ]
    atom.workspaceView.command "language-settings-edit:" + @_normalize(grammar), => @editSettings(grammar)

  editCurrent: ->
    grammar = atom.workspace.getActiveEditor()?.getGrammar()
    @editSettings grammar.name if grammar

  editSettings: (grammar) ->
    filename = @grammarDir + @_normalize(grammar) + ".cson"

    if not fs.existsSync filename
      @createSettingsFile filename, grammar

    atom.workspace.open filename

  createSettingsFile: (target, grammar) ->
    sourceJson = atom.config.defaultSettings.editor
    sourceCson = cson.stringifySync sourceJson

    fs.writeFileSync target, @_prepareSettingsFile(sourceCson, grammar)

  _prepareSettingsFile: (data, grammar) ->
    intro = [
      "# these are your #{grammar}-specific settings.",
      "# uncomment & edit lines to override global settings."
    ]

    lines = data.split('\n')
    lines = for line in lines
      if not line.match(/^[\{\}]$/)
        "  # " + line.trim()
      else
        line

    lines = intro.concat(lines)

    return lines.join('\n')

  mixConfig: (base, additional, output) ->
    baseJson = cson.parseFileSync base
    additionalJson = cson.parseFileSync additional
    baseJson.editor = _.extend(baseJson.editor || {}, additionalJson)

    fs.writeFileSync output, cson.stringifySync(baseJson)

  _normalize: (name) ->
    name = name.replace(/\s+/gi, '-')
    return jsesc name
