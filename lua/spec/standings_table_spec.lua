--- Triple Comment to Enable our LLS Plugin
describe('Standings Table from template', function()
	local StandingsTable = require('Module:Standings/Table')

	before_each(function()
		stub(mw.ext.LiquipediaDB, 'lpdb', {})
		stub(mw.ext.LiquipediaDB, 'lpdb_standingstable')
		stub(mw.ext.LiquipediaDB, 'lpdb_standingsentry')
	end)

	after_each(function()
		---@diagnostic disable-next-line: undefined-field
		mw.ext.LiquipediaDB.lpdb:revert()
		---@diagnostic disable-next-line: undefined-field
		mw.ext.LiquipediaDB.lpdb_standingstable:revert()
		---@diagnostic disable-next-line: undefined-field
		mw.ext.LiquipediaDB.lpdb_standingsentry:revert()
	end)

	it('renders group standings', function()
		local html = tostring(StandingsTable.fromTemplate{
			tabletype = 'group',
			title = 'Group A',
			import = 'false',
			round1 = {title = 'Week 1', started = 'true', finished = 'true'},
			round2 = {title = 'Week 2', started = 'true', finished = 'false'},
			{type = 'literal', name = 'Alpha', r1 = '3', r2 = '0'},
			{type = 'literal', name = 'Bravo', r1 = '1', r2 = '3'},
		})
		assert.is_truthy(html:find('standings-group', 1, true))
		assert.is_truthy(html:find('Group A', 1, true))
		assert.is_truthy(html:find('>Week 1<', 1, true))
		---@diagnostic disable-next-line: undefined-field
		local storedTable = mw.ext.LiquipediaDB.lpdb_standingstable.calls[1].vals[2]
		assert.are_equal('league', storedTable.type)
	end)

	it('applies the width to the table', function()
		local html = tostring(StandingsTable.fromTemplate{
			tabletype = 'group',
			import = 'false',
			width = '600px',
			round1 = {started = 'true', finished = 'true'},
			{type = 'literal', name = 'Alpha', r1 = '3'},
		})
		assert.is_truthy(html:find('class="table2[^"]*standings%-group"[^>]*style="width:600px"'))
	end)

	describe('imported match columns', function()
		local function queriesGames(args)
			StandingsTable.fromTemplate(args)
			---@diagnostic disable-next-line: undefined-field
			local matchQuery = mw.ext.LiquipediaDB.lpdb.calls[1]
			assert.are_equal('match2', matchQuery.vals[1])
			return matchQuery.vals[2].query:find('match2games', 1, true) ~= nil
		end

		it('leaves out the games when no tiebreaker reads them', function()
			assert.is_false(queriesGames{
				tabletype = 'swiss',
				round1 = {matches = 'M1'},
				tiebreakers = '["points", "gamediff", "buchholz"]',
			})
		end)

		it('includes the games for a tiebreaker that reads them', function()
			assert.is_true(queriesGames{
				tabletype = 'swiss',
				round1 = {matches = 'M1'},
				tiebreakers = '["points", "rounddiff"]',
			})
		end)

		it('includes the games with overtime', function()
			local Info = require('Module:Info')
			local originalStandingsConfig = Info.config.standings
			Info.config.standings = {overtime = {regulationRounds = 12}}
			local includesGames = queriesGames{tabletype = 'swiss', round1 = {matches = 'M1'}, overtime = 'true'}
			Info.config.standings = originalStandingsConfig
			assert.is_true(includesGames)
		end)
	end)

	describe('swiss imported matches', function()
		local MatchGroupUtil = require('Module:MatchGroup/Util')
		local TeamTemplateMock = require('wikis.commons.Mock.TeamTemplate')

		local function match2Opponent(template, score, placement)
			return {type = 'team', template = template, score = score, status = 'S', placement = placement,
				extradata = {}, match2players = {}}
		end

		local function match2Record(matchId, firstTemplate, secondTemplate)
			return {match2id = matchId, match2bracketid = 'abc', date = '2024-01-05', dateexact = '1', finished = '1',
				winner = '1', bestof = '3', extradata = {}, match2bracketdata = {}, match2games = {},
				match2opponents = {match2Opponent(firstTemplate, 2, 1), match2Opponent(secondTemplate, 0, 2)}}
		end

		before_each(function()
			TeamTemplateMock.setUp()
			---@diagnostic disable-next-line: undefined-field
			mw.ext.LiquipediaDB.lpdb:revert()
			stub(mw.ext.LiquipediaDB, 'lpdb', function(tableName)
				if tableName ~= 'match2' then
					return {}
				end
				return {
					match2Record('abc_R01-M001', 'heroic', 'tt9 esports 2022'),
					match2Record('abc_R01-M002', 'wolves esports', 'team liquid'),
				}
			end)
			spy.on(MatchGroupUtil, 'fetchMatchGroup')
		end)

		after_each(function()
			TeamTemplateMock.tearDown()
			---@diagnostic disable-next-line: undefined-field
			MatchGroupUtil.fetchMatchGroup:revert()
		end)

		it('shows the imported matches without fetching their match groups again', function()
			local html = tostring(StandingsTable.fromTemplate{
				tabletype = 'swiss',
				round1 = {matches = 'abc_R01-M001,abc_R01-M002'},
			})

			local _, overviewCount = html:gsub('standings%-match%-overview', '')
			assert.are_equal(4, overviewCount)
			assert.spy(MatchGroupUtil.fetchMatchGroup).was_not_called()
		end)
	end)

	it('errors on an unknown table type', function()
		assert.error(function()
			StandingsTable.fromTemplate{tabletype = 'league'}
		end)
	end)
end)
