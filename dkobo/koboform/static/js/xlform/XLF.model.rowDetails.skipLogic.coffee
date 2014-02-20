class XLF.SkipLogicCriterion extends XLF.BaseModel
  @expressionValues:
    # key: ["expressionString", "Descriptive Label", additionalValueRequired]
    resp_equals:    ["=", "was", true]
    resp_notequals: ["!=", "was not", true]
    ans_notnull:    ["!= NULL", "was answered", false]
    ans_null:       ["= ''", "was not answered", false]
    multiplechoice_selected: [null, null, true]

  defaults:
    "expressionCode": "resp_equals"
  initialize: (atts, opts)->
    ###
    This criterion holds 3 attributes:
    1. The other question
    2. The expression
    3. (optional) The response text
    ###
    unless opts.silent
      @linkUp()

  linkUp: ()->
    survey = @getSurvey()
    name = @get("name")
    if name
      question = survey.findRowByName(name)
      unless question
        throw new Error("Question with name `#{@get('name')}` not found")
      @set("question", question)

  serialize: ->
    if (question = @get("question"))
      questionName = question.getValue("name")
      if !questionName then return null
    else
      return null

    if (question.getType() == 'select_one')
      criterionName = @get('criterionOption')?.get('name') or @get('criterion')

      if criterionName
        "selected('#{questionName}', '#{criterionName}')"
      else
        console?.error("Criterion not specified", @)
        null
    else
      exCode = @get("expressionCode")
      unless exCode of @constructor.expressionValues
        throw new Error("ExpressionCode not recognized: #{exCode}")
      [exprStr, descLabel, addlReqs] = @constructor.expressionValues[exCode]

      wrappedCriterion = if addlReqs then ("'" + (@get('criterion') || '') + "'") else ""

      "${" + questionName + "} " + exprStr + " " + wrappedCriterion

class XLF.HandCodedSkipLogicCriterion extends XLF.SkipLogicCriterion
  initialize: (criteria) ->
    @set('value', criteria)
  serialize: () ->
    @get('value')
  linkUp: () ->

class XLF.SkipLogicCollectionMeta extends Backbone.Model
  defaults:
    "delimSelect": "and"
    "mode": "gui"

class XLF.SkipLogicCollection extends XLF.BaseCollection
  model: XLF.SkipLogicCriterion
  constructor: (items, options={})->
    @rowDetail = options.rowDetail
    @_parent = @rowDetail._parent
    @meta = new XLF.SkipLogicCollectionMeta()
    super(items, options)

  empty: ->
    @each (item)=> @remove(item)
    @
  serialize: ->
    joiners = {'or': " or ", 'and': " and "}
    joiner = @meta.get("delimSelect")
    throw new Error("Joiner not recognized: #{joiner}")  unless joiner of joiners
    _.compact(@map((item)=> item.serialize())).join(joiners[joiner])

  switchEditingMode: () ->
    if @meta.get("mode") == "gui"
      handcodedCriterion = new XLF.HandCodedSkipLogicCriterion(@serialize())
      @reset()
      @meta.set("mode", "handcode")
      @add(handcodedCriterion)
    else
      serialized = @serialize()
      XLF.parseHelper.parseSkipLogic(@, serialized, @_parent)
      if @parseable
        @meta.set("mode", "gui")
        @each((item) -> item.linkUp())
      else if serialized == ''
        @reset()
        @meta.set("mode", "gui")
      else
        @add(new XLF.HandCodedSkipLogicCriterion(serialized))
        alert("Could not parse: invalid / unsupported criteria")