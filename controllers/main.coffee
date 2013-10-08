

# vars


# console.log collections




createNewPlayer = (options) ->
  options.score = 0
  newPlayer = collections.Players.insert options
  collections.Games.update helpers.currentGame()._id,
    $push :
      players : newPlayer
  return newPlayer

correctAnswer = (player) ->
  collections.Players.update {_id:player},
    $inc: 
      score: helpers.currentGame().correctPoints 
  # create new game class

currentCorrectAnswer = ->
  if currentQuestion()
    for option in currentQuestion().options
      if option.correct
        return option
  return false 


getPlayer = (player) -> 
  if player?
    collections.Players.findOne player

getScore = (player) ->
  score = 0
  if getPlayer(player)?.answers
    for answer in getPlayer(player).answers
      if answer.answer.correct
        score+= helpers.currentGame().correctPoints
  return score


currentQuestion = ->
  questionId = helpers.currentStage().question_id
  if questionId
    collections.Questions.findOne({_id:questionId})


winningVideo = -> 1

if Meteor.isServer
  
  Meteor.methods
    'reset' : ->
      createNewGame()

    'quizComplete': ->
      winners = helpers.highestScorers helpers.currentPlayers()
      if winners.length is 1
        console.log 'We have one winner!'
        tiebreak.disable()
      else if winners.length > 1
        console.log 'Tiebreak situation'
        tiebreak.begin winners
        
    'newVideoVote': ->
      
      ###
      # needs fixing with some real math
      ### 

      if !helpers.currentGame().winningVideo?
        potentialVotes = helpers.currentPlayers().length
        numberOfVideos = 3

        minForVictory = 3
        
        videoVotes = _.countBy helpers.currentPlayers(), (player) ->
          player.video?.id
      

        for key,value of videoVotes      
          if key isnt 'undefined'
            if value >= minForVictory
              helpers.updateCurrentGame 
                winningVideo:key
              helpers.move 'forward'
              break

  createNewGame = ->
    console.log 'new game being created'
    defaultGame = collections.Config.findOne({_id:'defaultGame'})

    if !defaultGame?
      defaultGame =
        _id:'defaultGame'
        correctPoints : 100
        bonusPoints : 50
        position: 0
        stages: ['home',
        'register',
        'form',
        'home',
        'videoSelect',
        'home',
        'videoPlay',
        'home',
        'question',
        'answer',
        'question2',
        'answer2',
        'question3',
        'answer3',
        'question4',
        'answer4',
        'question5',
        'answer5',
        'question6',
        'answer6',
        'home',
        'results',
        'tiebreakIntro',
        'tiebreak',
        'tiebreakResults',
        'leaderboard',
        'home'],
        videos: [
          id: 1
          title:'Internet'
        ,
          id: 2
          title:'IP Law'
        ,
          id: 3
          title:'Antivirus'
        ,
          id: 4
          title:'Backup and Recovery'
        ,
          id: 5
          title:'Data Security'
        ,
          id: 6
          title:'Enterprise'
        ]

      collections.Config.insert defaultGame

    delete defaultGame._id
    collections.Games.insert defaultGame

  Meteor.startup ->
    if !helpers.currentGame()?
      createNewGame()
      insertFakeData()




if Meteor.isClient 
  # Session.delete()
  
  # pr
  $(document).on 'touchmove', (e) ->
    scrollable = false
    items = $(e.target).parents()
    $(items).each (i,o) ->
      if $(o).hasClass("scrollable")
        scrollable = true

    if !scrollable
        e.preventDefault()



  getURLParameter = (name) -> return decodeURIComponent((new RegExp("[?|&]#{name}=([^&;]+?)(&|##|;|$)").exec(location.search) || [null,""] )[1].replace(/\+/g, '%20'))||null;

  temporaryAdvance = ->
    inc = parseInt(Session.get('temporaryAdvance')) || 1
    Session.set 'temporaryAdvance', helpers.currentGame()?.position + inc
    console.log 'tempadv',Session.get('temporaryAdvance')

  if getURLParameter 'view'
    Session.set 'view', getURLParameter('view')
  else
    Session.set 'view', 'player'

  Handlebars.registerHelper 'bodyClass', -> Session.get 'view'
  Handlebars.registerHelper 'screenMode', -> Session.equals 'view', 'screen'
  Handlebars.registerHelper 'controllerMode', -> Session.equals 'view', 'control'
  Handlebars.registerHelper 'playerMode', -> Session.equals 'view', 'player'  
  Handlebars.registerHelper 'currentStage', -> helpers.currentStage()
  Handlebars.registerHelper 'currentPlayers', -> 
    console.log(helpers.currentPlayers())
    return helpers.currentPlayers()
  Handlebars.registerHelper 'currentCorrectAnswer', -> currentCorrectAnswer()
  Handlebars.registerHelper 'currentPlayer', -> helpers.currentPlayer()
  Handlebars.registerHelper 'currentQuestion', -> currentQuestion()

  Handlebars.registerHelper 'renderCurrentStage', ->   
    if helpers.currentStage()?.type
      new Handlebars.SafeString(Template["stage_#{helpers.currentStage()?.type}"](helpers.currentStage()));
  Handlebars.registerHelper 'createForm', (formObj) -> createForm formObj

  Template.controller.position = -> helpers.currentGame()?.position

  # ugh
  eventsObj = {}
  eventsObj["#{helpers.quickTouch} #forward-btn"] = -> helpers.move 'forward'
  eventsObj["#{helpers.quickTouch} #back-btn"] = -> helpers.move 'back'
  eventsObj["#{helpers.quickTouch} #reset-btn"] = -> Meteor.call 'reset'
  Template.controller.events eventsObj


  processForm = (stage, template) ->
    fields = []
    $(template.findAll('.collect-data')).each ->
      $this = $(this)
      fieldTitle = $.trim($('label',this).text())
      if $("[type='checkbox']",$this).size() > 0
        fieldValue = $("[type='checkbox']",$this).attr('checked')?
      else
        fieldValue = $('.input', $this).val()
      fields.push
        title:fieldTitle
        value:fieldValue

    collections.Forms.insert
      player: helpers.currentPlayer()
      stage_id: stage._id
      title: stage.title
      fields: fields

  Template.stage.allowedToSee = ->
    (helpers.currentStage()?.registration is true or helpers.currentPlayer() or Session.equals('view','screen'))


  # Template.stage_form.events
  #   "click #submit" : (e,t) ->
  #     temporaryAdvance()
  #     e.preventDefault()

  Template.stage_form.content = -> helpers.currentStage().content
  
  Template.stage_form.rendered = ->
    if @rendered != helpers.currentStage()._id
      $.jqBootstrapValidation('destroy')
      @rendered = helpers.currentStage()._id
      t = @
      $form = $("input,select,textarea",$(t.find('form'))).not("[type=submit]")
      submitted = false
      $form.jqBootstrapValidation
          submitSuccess: (form, e) ->
            e.preventDefault()
            if !submitted
              submitted = true
              if helpers.currentStage().registration
                thisCurrentPlayer = createNewPlayer 
                  firstname: t.find('[name="firstname"]').value
                  lastname: t.find('[name="lastname"]').value
                Session.set 'currentPlayer', thisCurrentPlayer
              processForm helpers.currentStage(), t
              temporaryAdvance()

  Template.modal.message = -> Session.get('modalData')


  Template.form_modal.events
    "click": (e,t) -> helpers.showModal @content
    

  # Template.controller_player_info.score = -> 
  #   getScore @._id
  # Template.question_content.voted = -> Session.equals 'voted', true
  # Template.question_content.created = -> Session.set 'voted', false
  # Template.player_info.myScore = ->
  #   getScore Session.get('currentPlayer')

  alreadyVoted = (playerId, questionId) ->
    if !getPlayer(playerId)?.answers
      return false
    for answer in getPlayer(playerId).answers
      if answer.question_id is questionId
        return true
    return false


  Template.stage_question.created = ->
    Session.set 'startedQuestion', new Date()
    Session.set 'timeUp', false
    clock.startCountdown 5, ->
      Session.set 'timeUp', true
      # alert 'voted'
      # Template.question_content.voted()
  Template.question_content.timeUp = -> Session.equals 'timeUp', true

  Template.question_content.voted = ->
    voted = alreadyVoted Session.get('currentPlayer'), helpers.currentStage().question_id
    console.log voted
    return voted

    # return voted
  eventsObj = {}
  eventsObj[helpers.quickTouch] = (evt, template) ->
    question = collections.Questions.findOne helpers.currentStage().question_id
    playerId = Session.get('currentPlayer')
    # already voted?
    if !alreadyVoted Session.get('currentPlayer'), helpers.currentStage().question_id 

      started = Session.get('startedQuestion')
      timeTaken = new Date() - started
      
      collections.Players.update Session.get('currentPlayer'),
        $push:
          answers:
            question: question.text
            question_id: question._id
            answer: @
            timeTaken: timeTaken
      
      collections.Players.update Session.get('currentPlayer'),
        $set:
          score: getScore playerId
    else
      console.log 'no multiple votes for you', Template.question_content.voted()

  Template.option.events eventsObj

  Template.stage_answer.correctPoints = -> helpers.currentGame().correctPoints
  Template.stage_answer.bonusPoints = -> helpers.currentGame().bonusPoints

  Template.stage_answer.answered = ->
    if Session.get('currentPlayer')?
      answers = getPlayer(Session.get('currentPlayer')).answers
      currentQuestionId = currentQuestion()._id
      if answers
        for answer in answers
          if answer.question_id is currentQuestionId
            return true
    return false


  Template.stage_answer.answeredCorrectly = ->
    answers = getPlayer(Session.get('currentPlayer')).answers?= []
    for answer in answers
      if answer.question_id is currentQuestion()._id
        if answer.answer.correct
          return true
    return false

  Template.stage_answer.gotBonus = -> true


  Template.stage_video_select.videos = -> helpers.currentGame().videos

  Template.stage_video_select.voted = -> Session.get 'votedOnVideo', true

  Template.video_button.events = 
    "click" : (evt, template) ->
      collections.Players.update Session.get('currentPlayer'),
        $set:
          video: @      
      Session.set 'votedOnVideo', true
      Meteor.call 'newVideoVote'
      # temporaryAdvance()


  Template.playing_video.winningVideo = -> winningVideo()

  Template.playing_video.created = ->
    Meteor.setTimeout ->
      $video = $('video')[0]
      $video.play()
      $video.addEventListener 'ended', ->
        helpers.move 'forward'
    , 100

  Template.stage_results.iAmWinner = ->
    thisPlayerId = helpers.currentPlayer()._id 
    for winner in helpers.highestScorers helpers.currentPlayers()
      if winner._id is thisPlayerId
        return true
        break
    return false


  Template.build_form.typeIs = (type) -> @.type is type

  Template.form_textbox.type = ->  @.validate || 'text'

  # Template.form_textbox.inputId = -> 


  # Template.form_textbox.required = -> if @.required then 'required' else ''

