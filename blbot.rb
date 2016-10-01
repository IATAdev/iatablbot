# iatablbot
# Requires editing to get this working correctly.
#
# Copyright (c) 2016, Italian Administrators Telegram Alliance
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of the project itself.
#
#
# Contributions to the code are welcome.

require 'telegram/bot'
require 'yaml'
require 'json'
require 'time'
require 'csv'
require 'open-uri'

## CONFIGURATION START ##
token = 'INSERT_YOUR_BOT_TOKEN_HERE'
channellink = "INSERIRE IL LINK AL CANALE NEWS QUI"
## CONFIGURATION END ##

## CONFIGURATION START ##
token = '236098200:AAFMwb_ICmkEFtR08--OcaXCk1dRC00Wbw4'
channellink = "https://telegram.me/IATABlacklist"
## CONFIGURATION END ##


channel = YAML.load(File.read('channel.conf')) rescue nil
admins = YAML.load(File.read('admins.conf')) rescue nil
userinfo = YAML.load(File.read('userinfo.list')) rescue Hash.new
status = Hash.new
juststarted = true

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::InlineQuery

    when Telegram::Bot::Types::Message
      if !userinfo[message.from.id].nil? then
        if userinfo[message.from.id]["banned"] == true then
          puts "Lol bannato"
          next
        end
      else
        userinfo[message.from.id] = Hash.new
        userinfo[message.from.id]["bld"] = false
      end

      if !message.document.nil? then
        if admins[message.from.id] then
          csv = bot.api.get_file(file_id: message.document.file_id)

          file_path = csv["result"]["file_path"]
          if file_path then
            csv_content = open("https://api.telegram.org/file/bot#{token}/#{file_path}").read
            begin
              CSV.parse(csv_content) do |row|
                if userinfo[row[2].to_i].nil? then
                  userinfo[row[2].to_i] = Hash.new
                end
                userinfo[row[2].to_i]["bld"] = true
                userinfo[row[2].to_i]["reason"] = row[3]
                userinfo[row[2].to_i]["defcon"] = row[4].to_i
              end
            rescue Exception => e
                bot.api.send_message(chat_id: message.from.id, text: "Errore nel parse del file inviato.\n" + e.message + "\n" + e.backtrace.inspect)
            end
            bot.api.send_message(chat_id: message.from.id, text: "Importazione effettuata.")
            next
          end
        end
      end

      reply = nil
      text = nil
      text_rl = message.text.dup rescue ''

      puts "Processing message -- #{text_rl}"

      if !message.forward_from.nil? then
        if admins[message.from.id] then
          if userinfo[message.forward_from.id].nil? then
            userinfo[message.forward_from.id] = Hash.new
          end
          userinfo[message.forward_from.id]["reason"] = "TBD"
          userinfo[message.forward_from.id]["defcon"] = 1
          userinfo[message.forward_from.id]["bld"] = true
          text = "Utente "
          if message.forward_from.username.nil? then
            text << message.forward_from.first_name << " "
            if !message.forward_from.last_name.nil? then
              text << message.forward_from.last_name << " "
            end
          else
            text << "@" << message.forward_from.username << " "
          end
          text << "\[#{message.forward_from.id}\] aggiunto alla lista."
        end
      end

      case message.text
      when /^\/start/i
        if userinfo[message.from.id].nil? then
          text = "*Buone notizie:* al momento non sei presente nella nostra lista nera."
        else
          if userinfo[message.from.id]["bld"] then
            text = "Ciao "
            text << message.from.first_name
            if !message.from.last_name.nil? then
              text << " " << message.from.last_name
            end
            text << ", temo che alcuni utenti di Telegram abbiano trovato "
            text << "il tuo comportamento scorretto e ti abbiano segnalato a IATA "
            text << "per verificare l'infrazione. I moderatori IATA hanno confermato "
            text << "la segnalazione e il tuo account è ora in lista nera con grado *"
            text << userinfo[message.from.id]["defcon"].to_s
            text << "* e motivazione *"
            text << userinfo[message.from.id]["reason"]
            text << "*\n\n"
            if userinfo[message.from.id]["defcon"] > 2 then
              text << "Mentre il tuo account è in blacklist, *potresti* non essere in "
              text << "grado di accedere ai gruppi che usano la nostra lista nera. "
              text << "\n\n"
            end
            text << "Puoi fare richiesta di rimozione utilizzando il comando /contact "
            text << "seguito dal messaggio. L'eventuale risposta ti verrà recapitata "
            text << "direttamente da questo stesso bot."
          else
            text = "*Buone notizie:* al momento non sei presente nella nostra lista nera."
          end
        end
        text << "\n\nTi ricordiamo che la nostra lista nera *non è in alcun modo affiliata "
        text << "a Telegram né al loro supporto*. Il tutto viene gestito da volontari ed "
        text << "utenti come te. Se hai comunque problemi nell'uso di Telegram, troverai "
        text << "altre informazioni sul nostro sito o con il comando /util."
        text << "\n\n"
        text << "Per ottenere la lista dei comandi usa il comando /help."
      when /^\/help/i
        text = "Benvenuto, i comandi che puoi usare con questo bot sono:\n"
        text << "/start - Verifica la tua presenza o meno in blacklist.\n"
        text << "/why \[id\] - Verifica la presenza di un ID in blacklist.\n"
        text << "/contact \[messaggio\] - Contatta gli amministratori.\n"
        text << "/channel - Ottieni il link del canale della blacklist.\n"
        text << "/util - Ottieni link di altri bot e canali utili."

      when /^\/util/i
        text = "@SpamBot - Bot ufficiale per verificare eventuali limitazioni imposte da Telegram\n"
        text << "@IATABlacklist - Canale della nostra lista nera\n"
        text << "@IATAlliance - Canale delle news del progetto IATA\n"
        text << "https://wikigram.it/ - Wiki italiana su Telegram, la più completa e precisa fonte di informazioni\n"
        text << "http://iata.ovh/ - Sito del progetto IATA e dei nostri collaboratori\n"
        text << "https://wikigram.it/home/index.php/Segnalazione\\_per\\_Spam - Descrizione delle meccaniche di spamban"

      when /^\/die/i
        if admins[message.from.id] == true then
          if juststarted == true then
            juststarted = false
            next
          end
          abort("Forced restart.")
        else
          text = "Non sei autorizzato ad usare questo comando."
        end

      when /^\/ban (.*)/i
        if admins[message.from.id] == true then
          if userinfo[$1.to_i] == nil then
            userinfo[$1.to_i] = Hash.new
            userinfo[$1.to_i]["banned"] = false
          end
          userinfo[$1.to_i]["banned"] = true
          text = "Utente aggiunto con successo ai bloccati."
        else
          text = "Non sei autorizzato ad utilizzare questo comando."
        end

      when /^\/unban (.*)/i
        if admins[message.from.id] == true then
          if userinfo[$1.to_i] == nil then
            userinfo[$1.to_i] = Hash.new
          end
          userinfo[$1.to_i]["banned"] = false
          text = "Utente rimosso con successo dai bloccati."
        else
          text = "Non sei autorizzato ad utilizzare questo comando."
        end

      when /^\/addadmin (.+)/i
        if admins == nil then
          admins = Hash.new
          admins[message.from.id] = true
          text = "Lista degli admin inizializzata. Sei stato aggiunto come primo admin."
          File.open('admins.conf', 'w') {|f| f.write(YAML.dump(admins))}
        else
          begin
            if admins[message.from.id] then
              admins[$1.to_i] = true
              text = "ID "
              text << $1 << " inserito con successo agli amministratori."
            else
              text = "Non sei autorizzato ad usare questo comando."
            end
          rescue
            text = "La struttura degli admin non è ancora stata inizializzata."
          end
        end

      when /^\/setchan/i
        begin
          if admins[message.from.id] == true then
            File.open('channel.conf', 'w') {|f| f.write(YAML.dump(message.chat))}
            channel = message.chat
            text = "Fatto."
          else
            text = "Non sei autorizzato ad usare questo comando."
          end
        rescue
          text = "La struttura degli admin non è ancora stata inizializzata."
        end

      when /^\/canale/i
        text = "Il canale della blacklist lo trovi al link: "
        text << channellink

      when /^\/why (.+)/i
        if userinfo[$1.to_i].nil? then
          text = "L'utente specificato non è in blacklist."
        else
          if userinfo[$1.to_i]["bld"] then
            text = "L'ID " << $1 << " è in blacklist con codice "
            text << userinfo[$1.to_i]["defcon"].to_s << ".\n"
            text << "Motivazione: " << userinfo[$1.to_i]["reason"]
          else
            text = "L'utente specificato non è in blacklist."
          end
        end

      when /^\/setreason (.+) (.*)/i
        if admins[message.from.id] then
          text = ""
          if userinfo[$1.to_i].nil? then
            userinfo[$1.to_i] = Hash.new
            userinfo[$1.to_i]["defcon"] = 1
            text << "Utente aggiunto con successo ai bloccati.\n"
          end
          userinfo[$1.to_i]["bld"] = true
          userinfo[$1.to_i]["reason"] = $2
          text << "Motivazione aggiornata con successo."
        else
          text = "Non sei autorizzato ad utilizzare questo comando."
        end

      when /^\/setdefcon (.+) (.+)/i
        if admins[message.from.id] then
          text = ""
          if userinfo[$1.to_i].nil? then
            userinfo[$1.to_i] = Hash.new
            userinfo[$1.to_i]["reason"] = "TBD"
            text << "Utente aggiunto con successo ai bloccati.\n"
          end
          userinfo[$1.to_i]["bld"] = true
          userinfo[$1.to_i]["defcon"] = $2.to_i
          text << "Codice aggiornato con successo."
        else
          text = "Non sei autorizzato ad utilizzare questo comando."
        end

      when /^\/unban (.+)/i
        if admins[message.from.id] then
          if userinfo[$1.to_i].nil? then
            text = "L'utente specificato non è nella blacklist."
          else
            userinfo.delete($1.to_i)
            text = "Utente rimosso dalla blacklist."
          end
        else
          text = "Non sei autorizzato ad utilizzare questo comando."
        end

      when /^\/savestate/i
        if admins[message.from.id] == true then
          File.open('userinfo.list', 'w') {|f| f.write(YAML.dump(userinfo))}
          text = "Fatto."
        else
          text = "Non sei autorizzato ad usare questo comando."
        end

      when /^\/contact (.*)/i
        removereq = "\#id"
        removereq << message.from.id << "\n"
        if message.from.username.nil? then
          removereq << message.from.first_name << " "
          if message.from.last_name.nil? then
            removereq << message.from.last_name << " "
          end
        else
          removereq << "@" << message.from.username << " "
        end
        removereq << "[#{message.from.id}]\n\n"
        removereq << "Messaggio: " << $1
        bot.api.send_message(chat_id: channel.id, text: removereq)

      when /^\/dumpjson/i
        parsed_uinfo = Hash.new
        userinfo.each do |key, value|
          if value["bld"] then
            parsed_uinfo[key] = Hash.new
            parsed_uinfo[key]["code"] = value["defcon"]
            parsed_uinfo[key]["reason"] = value["reason"]
          end
        end
        File.open('blacklist.json', 'w') {|f| JSON.dump(parsed_uinfo, f)}
        bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new('blacklist.json', 'multipart/form-data'), caption: "\#json #{Time.now.utc.iso8601}")
        next

      when /^\//i
        text = "Comando sconosciuto."

      else
        if message.reply_to_message
          if message.reply_to_message.from.id == bot_id
            if message.reply_to_message.text.start_with?("\#id") then
              if admins[message.from.id] then
                reply = "Risposta da parte di un admin:\n"
                reply << message.text << "\n"
                reply << "Puoi rispondere utilizzando di nuovo il comando /contact."
                replytoid = message.reply_to_message.text.lines.first.chomp
                replytoid.slice! "\#id"
                bot.api.send_message(chat_id: replytoid.to_i, text: reply)
                next
              end
            end
          end
        end

      end

      if text.nil? then
        next
      end

      bot.api.send_message(chat_id: message.chat.id, text: text, parse_mode: "Markdown", disable_web_page_preview: true)
    else
      next
    end
  end
end
