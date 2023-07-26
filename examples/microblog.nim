import debby/sqlite, debby/pools, mummy, mummy/routers, std/strutils,
    std/strformat

# You need to create a data base pool because mummy is multi threaded and
# you can't use a DB connection from multiple threads at once.
let pool = newPool()

# After creating a pool you should open connections.
# Most DB's only allow about ~10, but this can be configured at DB level.
for i in 0 ..< 10:
  pool.add(openDatabase("examples/microblog.db"))

# Debby users simple Nim objects as table definition.
type Post = ref object
  id: int
  title: string
  author: string
  tags: string
  postDate: string
  body: string

# In order to use a pool, call `withDb:`, this will inject a `db` variable so
# that you can query a db. It will return the db back to the pool after.
pool.withDb:
  if not db.tableExists(Post):
    # When running this for the first time, it will create the table
    # and populate it with dummy data.
    db.createTable(Post)
    db.insert(Post(
      title: "First post!",
      author: "system",
      tags: "autogenerated, system",
      postDate: "today",
      body: "This is how to create a post"
    ))
    db.insert(Post(
      title: "Second post!",
      author: "system",
      tags: "autogenerated, system",
      postDate: "yesterday",
      body: "This is how to create a second post"
    ))
  else:
    # Its always a good idea to check if your tables in the db match the
    # nim objects. If they don't match you will see an exception.
    db.checkTable(Post)

proc indexHandler(request: Request) =
  pool.withDb:
    # Generate the HTML for index.html page.
    var x = ""
    x.add "<h1>Micro Blog</h1>"
    x.add "<ul>"
    for post in db.filter(Post):
      x.add &"<li><a href='/posts/{post.id}'>{post.title}</a></li>"
    x.add "</ul>"

    var headers: HttpHeaders
    headers["Content-Type"] = "text/html"
    request.respond(200, headers, x)

proc postHandler(request: Request) =
  # Generate the HTML for /posts/123 page.
  var x = ""
  let id = request.uri.rsplit("/", maxSplit = 1)[^1].parseInt()
  let post = pool.get(Post, id)
  x.add &"<h1>{post.title}</h1>"
  x.add &"<h2>by {post.author}</h2>"
  x.add post.body

  var headers: HttpHeaders
  headers["Content-Type"] = "text/html"
  request.respond(200, headers, x)

# Set up a mummy router
var router: Router
router.get("/", indexHandler)
router.get("/posts/*", postHandler)

# Set up mummy server
let server = newServer(router)
echo "Serving on http://localhost:8080"
server.serve(Port(8080))
