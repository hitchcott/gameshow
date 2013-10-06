tiebreakStageList = ['tiebreakIntro','tiebreak','tiebreakResults']

buttons = [{t:'0',d:0},{t:'1',d:1},{t:'2',d:2},{t:'3',d:3},{t:'4',d:4},{t:'5',d:5},{t:'6',d:6},{t:'7',d:7},{t:'8',d:8},{t:'9',d:9},{t:'×',d:'backspace',c:'backspace'}]

duration =
  phase1 : 5 
  phase2 : 10

numberLength = 10

tieBreakIntroStage = undefined

@tiebreak = 
  begin : (winners) ->
    tieBreakIntroStage = helpers.currentGame().position + 2
    console.log 'tieBreakIntroStage', tieBreakIntroStage
    helpers.updateCurrentGame 
      tiebreak: 
        currentRound: 0
        phase: 1
        rounds: [
          players: winners
          numbers: generateNumbers()
          created: new Date()
        ]

  disable: ->
    filteredStages = _.filter helpers.currentGame().stages, (stage) ->
      !(tiebreakStageList.indexOf(stage) >= 0)
    helpers.updateCurrentGame 
      stages: filteredStages


newRound = ->
  currentRounds = tiebreakConfig().rounds
  currentRounds.push 
    players: tiebreakWinners()
    numbers: generateNumbers()
    created: new Date()

  helpers.updateCurrentGame 
    tiebreak: 
      currentRound: currentRound()+1
      phase: 1
      rounds: currentRounds

  helpers.move tieBreakIntroStage

if Meteor.isServer
  
  Meteor.methods
    'tiebreakComplete': ->
      if tiebreakWinner()
        helpers.updateCurrentGame {'tiebreak.complete' : true}
        helpers.move 'forward'
      else
        newRound()
        



tiebreakConfig = -> helpers.currentGame().tiebreak

currentRound = -> tiebreakConfig().currentRound

currentTiebreak = -> tiebreakConfig().rounds[currentRound()]

generateNumbers = -> 
  str = ''
  for [1..numberLength]
    str+= Math.floor(Math.random()*10)
  return str
  

setPhase = (phase) -> 
  Session.set "tiebreakPhase", phase
  helpers.updateCurrentGame {'tiebreak.phase' : phase}


correctNumbers = (guess,answer) ->
  correct = 0
  for i in [0..guess.length]
    if guess[i] is answer[i]
      correct++
    else
      return correct
      break

sendTiebreakScore = ->
  console.log 'sending score'
  tiebreakScore = correctNumbers Session.get('tiebreakNumbers'), currentTiebreak().numbers
  collections.Players.update {_id:helpers.currentPlayer()._id},
    $push: 
      tiebreakScore: tiebreakScore

tiebreakResults = ->
  topList = []
  for player in currentTiebreak().players
    thisPlayer = collections.Players.findOne({_id:player._id})
    console.log currentRound(), thisPlayer.tiebreakScore, thisPlayer.tiebreakScore[currentRound()]
    if thisPlayer.tiebreakScore
      thisPlayer.score = thisPlayer.tiebreakScore[currentRound()]
      topList.push thisPlayer
  console.log topList
  topList.sort (a,b) ->
    a.score - b.score
  topList.reverse()
# method, start tiebreak

tiebreakWinners = ->  helpers.highestScorers tiebreakResults()

tiebreakWinner = -> if tiebreakWinners().length is 1 then tiebreakWinners()[0] else false

if Meteor.isClient

  myNumberString = -> Session.get('tiebreakNumbers')

  playing = ->
    if Session.equals('view', 'screen')
      return true
    else
      currentPlayer = helpers.currentPlayer()
      match = false
      console.log 'playing',currentTiebreak().players
      for player in currentTiebreak().players
        if currentPlayer._id is player._id
          match = true
      return match



  Template.tiebreak_numbers.created = -> 
    # dispaly
    setPhase 1
    Session.set "tiebreakComplete", false
    clock.startCountdown duration.phase1, ->
      setPhase 2
      clock.startCountdown duration.phase2, {big : true}, ->
        Session.set "tiebreakComplete", true

  Template.tiebreak_number_input.created = (template) ->
    # client
    Session.set 'tiebreakNumbers', ''
    console.log 'phase is ', tiebreakConfig().phase
    clock.startCountdown duration.phase2, ->
      Session.set "tiebreakComplete", true
      sendTiebreakScore()


  Template.tiebreak_number_input.buttons = -> buttons

  Template.tiebreak_number_input.numberString = -> myNumberString()
      
  eventsObj = {}
  eventsObj[helpers.quickTouch] = (e,t) ->
    if @d isnt 'backspace'
      newString = myNumberString() + @d 
    else
      newString = myNumberString().slice(0,-1)
    Session.set 'tiebreakNumbers', newString

  Template.number_input_button.events eventsObj


  Handlebars.registerHelper 'tiebreakPlayer', -> playing()

  Template.tiebreak_numbers.numbers = -> currentTiebreak().numbers
  Template.stage_results.playingTiebreak = -> tiebreakConfig()
  Template.stage_tiebreak.phaseOne = -> tiebreakConfig().phase is 1
  Template.stage_tiebreak.phaseTwo = -> tiebreakConfig().phase is 2

  Template.stage_tiebreak.created = -> Session.set 'tiebreakComplete', false
  
  Template.stage_tiebreak.tiebreakComplete = -> Session.equals 'tiebreakComplete', true

  Template.stage_tiebreakResults.winner = -> tiebreakWinner()

  Template.stage_tiebreakResults.tiebreakResults = -> tiebreakResults()




