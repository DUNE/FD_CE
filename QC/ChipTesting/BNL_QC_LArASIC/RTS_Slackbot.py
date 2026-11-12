import os
import threading
import time
import keyring
import getpass
import logging
from PIL import Image

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler


def set_channel_id():
    try:
        channel = getpass.getpass('Enter channel ID:')
    except:
        print('[SLACKBOT] Could not get channel ID from user input')
        raise ValueError

    try:
       keyring.set_password("RTS_SLACK", "CHANNEL_ID", channel)
    except:
        print('[SLACKBOT] Could not store channel ID in keyring')
        raise ValueError
    print('Channel ID set')

def set_bot_token():
    try:
        bot_token = getpass.getpass('Enter bot token:')
    except:
        print('[SLACKBOT] Could not get bot token from user input')
        raise ValueError

    try:
        keyring.set_password("RTS_SLACK","BOT_TOKEN", bot_token)
    except:
        print('[SLACKBOT] Could not store bot token in keyring')
        raise ValueError
    print('Bot token set')

def set_app_token():
    try:
        app_token = getpass.getpass('Enter app token:')
    except:
        print('[SLACKBOT] Could not get app token from user input')
        raise ValueError

    try:
        keyring.set_password("RTS_SLACK","APP_TOKEN", app_token)
    except:
        print('[SLACKBOT] Could not store app token in keyring')
        raise ValueError
    print('App token set')

def force_set_secrets():
    print('[SLACKBOT] Initializing RTS SlackBot, will search for secrets in Windows crentials manager (keyring)')
    set_channel_id()
    while True:
        cid = keyring.get_password("RTS_SLACK","CHANNEL_ID") #  os.environ["RTS_SLACK_CHANNEL"]
        if cid is None:
            print('[SLACKBOT] Channel ID not set, please submit it')
            set_channel_id()
        else:
            break
    
    set_bot_token()
    while True:
        bot_token = keyring.get_password("RTS_SLACK","BOT_TOKEN")   #os.environ["RTS_SLACK_BOT_TOKEN"]
        if bot_token is None:
            print('[SLACKBOT] Bot token not set, please submit it')
            set_bot_token()
        else:
            break

    set_app_token()
    while True:
        app_token = keyring.get_password("RTS_SLACK","APP_TOKEN")   #os.environ["RTS_SLACK_APP_TOKEN"]
        if app_token is None:
            print('[SLACKBOT] App token not set, please submit it')
            set_app_token()
        else:
            break

class SlackBot():

    def __init__(self):
        print('[SLACKBOT] Initializing RTS SlackBot, will search for secrets in Windows crentials manager (keyring)')
        while True:
            self.channel = keyring.get_password("RTS_SLACK","CHANNEL_ID") #  os.environ["RTS_SLACK_CHANNEL"]
            if self.channel is None:
                print('[SLACKBOT] Channel ID not set, please submit it')
                set_channel_id()
            else:
                break

        while True:
            self.bot_token = keyring.get_password("RTS_SLACK","BOT_TOKEN")   #os.environ["RTS_SLACK_BOT_TOKEN"]
            if self.bot_token is None:
                print('[SLACKBOT] Bot token not set, please submit it')
                set_bot_token()
            else:
                break

        while True:
            self.app_token = keyring.get_password("RTS_SLACK","APP_TOKEN")   #os.environ["RTS_SLACK_APP_TOKEN"]
            if self.app_token is None:
                print('[SLACKBOT] App token not set, please submit it')
                set_app_token()
            else:
                break
        
        self.app = App(token=self.bot_token)
        self.client = self.app.client

        self.handler = SocketModeHandler(self.app, self.app_token)

        # Responses indexed by original message timestamp
        self.responses = {}
        self.lock = threading.Lock()
        self.condition = threading.Condition(self.lock)


        self.app.action("button_yes")(self._handle_button)
        self.app.action("button_no")(self._handle_button)

        self.app.event("reaction_added")(self._handle_reaction)
        self.app.event("message")(self._handle_message)

    def start(self):
        """Start listening for Slack events in the background."""
        self.handler.connect()
        print('[SLACKBOT] connected')

    def stop(self):
        """Stop the Slack Socket Mode connection."""        
        self.handler.close()
        print('[SLACKBOT] disconnected')

    def send_message(self, text, thread_ts=None, buttons=None):
        """Send a message and return its timestamp."""
        print(f'[SLACKBOT] send_message: message=("{text}"), ts={thread_ts}, buttons={buttons}')
        kwargs = {
            "channel": self.channel,
            "text": text
        }

        if thread_ts is not None:
            kwargs["thread_ts"] = thread_ts

        if buttons:
            elements = []

            for button in buttons:
                element = {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": button["text"]
                    },
                    "action_id": button["action_id"],
                    "value": button["value"]
                }

                if "style" in button:
                    element["style"] = button["style"]

                elements.append(element)

            kwargs["blocks"] = [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": text
                    }
                },
                {
                    "type": "actions",
                    "elements": elements
                }
            ]

        response = self.client.chat_postMessage(**kwargs)
        return response["ts"]

    def send_image(self, image_path, text="", title="Image"):
        """Upload an image and return its message timestamp."""

        print('[SLACKBOT] Creating tmp image for slack')
        try:
            
            img=Image.open(image_path)
            img=img.convert("RGB")
            tmp_image=os.path.join(os.path.dirname(image_path),"slack_tmp_image.jpg")
            img.save(tmp_image,"JPEG",quality=95)

            print(f'{tmp_image}')
        except Exception as e:
            print('[SLACKBOT] Could not convert image to jpg')
            print('Error message:', repr(e))
            raise

        if tmp_image is None:
            print('No tmp image')
            raise ValueError("No tmp image created")

        try:
            response = self.client.files_upload_v2(
                channel=self.channel,
                file=tmp_image,
                title=title,
                initial_comment=text
            )
        except Exception as e:
            print('[SLACKBOT] Unable to upload image file')
            print('Error message:', repr(e))
            raise
        finally:
            print(f'[SLACKBOT] Removing tmp file {tmp_image}')
            os.remove(tmp_image)


        # files_upload_v2 returns the uploaded file.
        # Find the message that shared it.
        file_info = response["files"][0]
        file_id = file_info["id"]

        # Retrieve file information, including its shares.
        info = self.client.files_info(file=file_id)
        shares = info["file"].get("shares", {})

        ts = None
        time.sleep(0.5)
        # Slack may take a short time to populate the share information.
        for attempt in range(10):
            info = self.client.files_info(file=file_id)
            shares = info["file"].get("shares", {})

            for share_type in ("public", "private"):
                channel_shares = shares.get(share_type, {}).get(
                    self.channel, []
                )

                if channel_shares:
                    return channel_shares[0]["ts"]

            time.sleep(0.5)

        raise RuntimeError(
            f"Image uploaded (file ID: {file_id}), "
            "but its channel message timestamp could not be determined."
        )

    
    def _handle_button(self, ack, body):
        """Handle interactive button clicks."""

        # Slack requires interactions to be acknowledged promptly.
        ack()

        channel = body.get("channel", {}).get("id")

        if channel != self.channel:
            return

        message = body.get("message", {})
        ts = message.get("ts")

        actions = body.get("actions", [])

        if not actions or ts is None:
            return

        action = actions[0]

        response = {
            "type": "button",
            "value": action.get("value"),
            "user": body.get("user", {}).get("id"),
            "ts": ts
        }

        self._record_response(ts, response)


    def _handle_reaction(self, event):
        """Handle emoji reactions."""

        item = event.get("item", {})

        if item.get("type") != "message":
            return

        if item.get("channel") != self.channel:
            return

        ts = item.get("ts")

        response = {
            "type": "reaction",
            "reaction": event.get("reaction"),
            "user": event.get("user"),
            "ts": ts
        }

        self._record_response(ts, response)

    def _handle_message(self, event):
        """Handle replies in threads."""

        if event.get("channel") != self.channel:
            return

        # Ignore bot messages and message updates.
        if event.get("bot_id") or event.get("subtype"):
            return

        thread_ts = event.get("thread_ts")

        # Only process threaded replies.
        if thread_ts is None:
            return

        response = {
            "type": "message",
            "text": event.get("text"),
            "user": event.get("user"),
            "ts": event.get("ts")
        }

        self._record_response(thread_ts, response)

    def _handle_terminal_input(self, ts):
            """Wait for terminal input and record it as a response."""
    
            try:
                value = input("Enter response: ")
            except EOFError:
                return
    
            response = {
                "type": "terminal",
                "text": value,
                "user": "local",
                "ts": ts
            }
    
            self._record_response(ts, response)

    def _record_response(self, ts, response):
        """Store responses and wake waiting threads."""

        with self.condition:
            self.responses.setdefault(ts, []).append(response)
            self.condition.notify_all()

    
    def wait_for_response(self, ts, timeout=None,
                        allowed_reactions=None,
                        terminal_input=False):

        if terminal_input:
            threading.Thread(
                target=self._handle_terminal_input,
                args=(ts,),
                daemon=True
            ).start()

        deadline = (
            None if timeout is None
            else time.monotonic() + timeout
        )

        with self.condition:
            while True:
                queue = self.responses.get(ts, [])

                for i, response in enumerate(queue):

                    if response["type"] == "reaction":
                        if allowed_reactions is not None:
                            if response["reaction"] not in allowed_reactions:
                                continue

                    return queue.pop(i)

                remaining = (
                    None if deadline is None
                    else deadline - time.monotonic()
                )

                if remaining is not None and remaining <= 0:
                    return None

                self.condition.wait(timeout=remaining)

def test_simple_message(bot):
    try:
        print(f'Sending message to channel ({bot.channel})')
        #response = bot.client.chat_postMessage(channel=bot.channel,text='Simple message from RTS')
        bot.send_message('RTS TEST MESSAGE: Simple message with slack bolt API')
    except Exception as e:
        print('[SLACKBOT] ERROR: Could not send message')
        print('Error message:', repr(e))
        return False

    # print('Response:')
    # print(response)

    return True

def test_message_with_button_response(bot):

    try:
        ts = bot.send_message(
            'RTS TEST MESSAGE: Please press one of the buttons in the next minute',
            buttons=[
                {
                    "action_id": "button_yes",
                    "text": "Yes", 
                    "value": "Y",
                    "style": "primary"
                },
                {
                    "action_id": "button_no",
                    "text": "No", 
                    "value": "N", 
                    "style": "danger"
                }
            ]
        )
    except Exception as e:
        print('[SLACKBOT] ERROR: Could not send message')
        print('Error message:', repr(e))
        return

    print('Message sent, waiting for response')
    response = bot.wait_for_response(ts,timeout=60)

    if response is None:
        print('[SLACKBOT] No response')
        tst=bot.send_message('Too slow!', thread_ts=ts)
    elif response['type'] == 'button':
        print('[SLACKBOT] Button clicked')

        if response['value'] == "Y":
            print('[SLACKBOT] Someone on slack clicked "Yes"!')
            tst=bot.send_message('Thank you for clicking "yes"', thread_ts=ts)
            return True
        elif response['value']=="N":
            print('[SLACKBOT] Someone on slack clicked "No"!')
            tst=bot.send_message('Thank you for clicking "no"', thread_ts=ts)
            return True
        else:
            print('[SLACKBOT] Unspecified response!')
            return False
        
    elif response["type"] == "reaction":
        print("[SLACKBOT] Emoji reaction:", response["reaction"])
        bot.send_message('I said click a button, not react. Nevermind.', thread_ts=ts)
        return False

    elif response["type"] == "message":
        print("[SLACKBOT] Thread reply:", response["text"])
        bot.send_message('I said click a button, not reply. Nevermind.', thread_ts=ts)
        return False

    else:
        "[SLACKBOT] Other response given"
        return False

    return True


def test_send_image_and_await_response(bot):

    test_image = "C:/Users/neutrino/LArASIC_Testing/Tested/M002T9970/images/DF/Socket/Insert/20261103141138_DAT2_Skt8_insert.bmp"

    try:
        ts = bot.send_image(test_image, 'This is a test for sending an image', 'Test Image')
    except Exception as e:
        print('[SLACKBOT] ERROR: Could not send image')
        print('Error message:', repr(e))
        return False

    try:
        ts = bot.send_message(
            'RTS TEST MESSAGE: Does this look okay?',
            thread_ts=ts,
            buttons=[
                {
                    "action_id": "button_yes",
                    "text": "Yes", 
                    "value": "Y",
                    "style": "primary"
                },
                {
                    "action_id": "button_no",
                    "text": "No", 
                    "value": "N", 
                    "style": "danger"
                }
            ]
        )
    except Exception as e:
        print('[SLACKBOT] ERROR: Could not send message')
        print('Error message:', repr(e))
        return False

    print('Message sent, waiting for response')
    response = bot.wait_for_response(ts,timeout=60)

    if response is None:
        print('[SLACKBOT] No response')
        tst=bot.send_message('Too slow!', thread_ts=ts)
    elif response['type'] == 'button':
        print('[SLACKBOT] Button clicked')

        if response['value'] == "Y":
            print('[SLACKBOT] Someone on slack clicked "Yes"!')
            tst=bot.send_message('Thank you for clicking "yes"', thread_ts=ts)
            return True
        elif response['value']=="N":
            print('[SLACKBOT] Someone on slack clicked "No"!')
            tst=bot.send_message('Thank you for clicking "no"', thread_ts=ts)
            return True
        else:
            print('[SLACKBOT] Unspecified response!')
            return False
        
    elif response["type"] == "reaction":
        print("[SLACKBOT] Emoji reaction:", response["reaction"])
        # bot.send_message('I said click a button, not react. Nevermind.', thread_ts=ts)
        return False

    elif response["type"] == "message":
        print("[SLACKBOT] Thread reply:", response["text"])
        # bot.send_message('I said click a button, not reply. Nevermind.', thread_ts=ts)
        return False

    else:
        "[SLACKBOT] Other response given"
        return False

    return True


# # def test_message_with_emoji_response(bot):
# #     try:
# #         bot.send_message('RTS TEST MESSAGE: Please react with the green tick box emoji')
# #     except:
# #         print('[SLACKBOT] ERROR: Could not send message')

# # def test_message_with_text_response(bot):
# #     try:
# #         bot.send_message('RTS TEST MESSAGE: Please say the magic word')
# #     except:
# #         print('[SLACKBOT] ERROR: Could not send message')

# # def test_image_message(bot):
# #     test_image = "C:/Users/neutrino/LArASIC_Testing/Tested/M002T9970/images/DF/Socket/Insert/20261103141138_DAT2_Skt8_insert.bmp"
    
# #     try:
# #         bot.send_image(test_image, 'This is a test for sending an image', 'Test Image')
# #     except:
# #         print('[SLACKBOT] ERROR: Could not send image')
    
# #     pass


def run_tests(bot):

    results={}
    try:
        bot.start()
    except:
        print ('Cannot connect to socket')
        return

    try:
        # result=test_simple_message(bot)
        # results['SimpleMessage']=result

        # result=test_message_with_button_response(bot)
        # results['ButtonMessage']=result

        result=test_send_image_and_await_response(bot)
        results['ImageAndButton']=result

    except:
        print('ERROR: Test failures')
        results['TestsRun']=False
        return
    finally:
        print('Results:')
        print(results)
        bot.stop()

    if all(results):
        print('Success!')

def main():


    # while True:
    #     inyn=input('Reset info? (Y/N): ')
    #     if inyn.lower() in ['y','yes']:
    #         force_set_secrets()
    #         break
    #     if inyn.lower() in ['n','no']:
    #         break

    try:
        bot = SlackBot()
    except:
        print('Could not initialize slackbot')
        exit(1)

    # while True:
    #     inyn=input('Run tests? (Y/N):')
    #     if inyn.lower() in ['y','yes']:
    #         break
    #     if inyn.lower() in ['n','no']:
    #         exit(0)

    try:
        run_tests(bot)
    except:
        print('ERROR: Tests failed')
        exit(1)

    print('Program finished')
    return

if __name__=="__main__":
    try:
        main()
    except:
        print('SlackBot: Main failed')


# ### TESTING

# logging.basicConfig(level=logging.DEBUG)

# app = App(token=keyring.get_password("RTS_SLACK","BOT_TOKEN"))

# handler = SocketModeHandler(
#     app,
#     keyring.get_password("RTS_SLACK","APP_TOKEN")
# )

# print("Connecting to Slack...")

# handler.connect()

# print("Connection established.")

# input("Press Enter to disconnect...")

# handler.close()