The `alias.many` command can be used to copy definitions from the current namespace into your curated one.
The names that will be used in the target namespace are the names you specify, relative to the current namespace:

```
.> help alias.many

  alias.many (or copy)
  `alias.many <relative1> [relative2...] <namespace>` creates aliases `relative1`, `relative2`, ...
  in the namespace `namespace`.
  `alias.many foo.foo bar.bar .quux` creates aliases `.quux.foo.foo` and `.quux.bar.bar`.

```

Let's try it!

```ucm
.> cd .builtin

.builtin> find

  1.   builtin type Any
  2.   Any.Any : a -> Any
  3.   Any.unsafeExtract : Any -> a
  4.   builtin type Boolean
  5.   Boolean.not : Boolean -> Boolean
  6.   bug : a -> b
  7.   builtin type Bytes
  8.   Bytes.++ : Bytes -> Bytes -> Bytes
  9.   Bytes.at : Nat -> Bytes -> Optional Nat
  10.  Bytes.decodeNat16be : Bytes -> Optional (Nat, Bytes)
  11.  Bytes.decodeNat16le : Bytes -> Optional (Nat, Bytes)
  12.  Bytes.decodeNat32be : Bytes -> Optional (Nat, Bytes)
  13.  Bytes.decodeNat32le : Bytes -> Optional (Nat, Bytes)
  14.  Bytes.decodeNat64be : Bytes -> Optional (Nat, Bytes)
  15.  Bytes.decodeNat64le : Bytes -> Optional (Nat, Bytes)
  16.  Bytes.drop : Nat -> Bytes -> Bytes
  17.  Bytes.empty : Bytes
  18.  Bytes.encodeNat16be : Nat -> Bytes
  19.  Bytes.encodeNat16le : Nat -> Bytes
  20.  Bytes.encodeNat32be : Nat -> Bytes
  21.  Bytes.encodeNat32le : Nat -> Bytes
  22.  Bytes.encodeNat64be : Nat -> Bytes
  23.  Bytes.encodeNat64le : Nat -> Bytes
  24.  Bytes.flatten : Bytes -> Bytes
  25.  Bytes.fromBase16 : Bytes -> Either Text Bytes
  26.  Bytes.fromBase32 : Bytes -> Either Text Bytes
  27.  Bytes.fromBase64 : Bytes -> Either Text Bytes
  28.  Bytes.fromBase64UrlUnpadded : Bytes -> Either Text Bytes
  29.  Bytes.fromList : [Nat] -> Bytes
  30.  Bytes.gzip.compress : Bytes -> Bytes
  31.  Bytes.gzip.decompress : Bytes -> Either Text Bytes
  32.  Bytes.size : Bytes -> Nat
  33.  Bytes.take : Nat -> Bytes -> Bytes
  34.  Bytes.toBase16 : Bytes -> Bytes
  35.  Bytes.toBase32 : Bytes -> Bytes
  36.  Bytes.toBase64 : Bytes -> Bytes
  37.  Bytes.toBase64UrlUnpadded : Bytes -> Bytes
  38.  Bytes.toList : Bytes -> [Nat]
  39.  Bytes.zlib.compress : Bytes -> Bytes
  40.  Bytes.zlib.decompress : Bytes -> Either Text Bytes
  41.  builtin type Char
  42.  Char.fromNat : Nat -> Char
  43.  Char.toNat : Char -> Nat
  44.  Char.toText : Char -> Text
  45.  builtin type Code
  46.  Code.cache_ : [(Term, Code)] ->{IO} [Term]
  47.  Code.dependencies : Code -> [Term]
  48.  Code.deserialize : Bytes -> Either Text Code
  49.  Code.display : Text -> Code -> Text
  50.  Code.isMissing : Term ->{IO} Boolean
  51.  Code.lookup : Term ->{IO} Optional Code
  52.  Code.serialize : Code -> Bytes
  53.  Code.validate : [(Term, Code)] ->{IO} Optional Failure
  54.  crypto.hash : HashAlgorithm -> a -> Bytes
  55.  builtin type crypto.HashAlgorithm
  56.  crypto.HashAlgorithm.Blake2b_256 : HashAlgorithm
  57.  crypto.HashAlgorithm.Blake2b_512 : HashAlgorithm
  58.  crypto.HashAlgorithm.Blake2s_256 : HashAlgorithm
  59.  crypto.HashAlgorithm.Sha1 : HashAlgorithm
  60.  crypto.HashAlgorithm.Sha2_256 : HashAlgorithm
  61.  crypto.HashAlgorithm.Sha2_512 : HashAlgorithm
  62.  crypto.HashAlgorithm.Sha3_256 : HashAlgorithm
  63.  crypto.HashAlgorithm.Sha3_512 : HashAlgorithm
  64.  crypto.hashBytes : HashAlgorithm -> Bytes -> Bytes
  65.  crypto.hmac : HashAlgorithm -> Bytes -> a -> Bytes
  66.  crypto.hmacBytes : HashAlgorithm
                          -> Bytes
                          -> Bytes
                          -> Bytes
  67.  Debug.trace : Text -> a -> ()
  68.  Debug.watch : Text -> a -> a
  69.  unique type Doc
  70.  Doc.Blob : Text -> Doc
  71.  Doc.Evaluate : Term -> Doc
  72.  Doc.Join : [Doc] -> Doc
  73.  Doc.Link : Link -> Doc
  74.  Doc.Signature : Term -> Doc
  75.  Doc.Source : Link -> Doc
  76.  structural type Either a b
  77.  Either.Left : a -> Either a b
  78.  Either.Right : b -> Either a b
  79.  structural ability Exception
  80.  Exception.raise : Failure ->{Exception} x
  81.  builtin type Float
  82.  Float.* : Float -> Float -> Float
  83.  Float.+ : Float -> Float -> Float
  84.  Float.- : Float -> Float -> Float
  85.  Float./ : Float -> Float -> Float
  86.  Float.abs : Float -> Float
  87.  Float.acos : Float -> Float
  88.  Float.acosh : Float -> Float
  89.  Float.asin : Float -> Float
  90.  Float.asinh : Float -> Float
  91.  Float.atan : Float -> Float
  92.  Float.atan2 : Float -> Float -> Float
  93.  Float.atanh : Float -> Float
  94.  Float.ceiling : Float -> Int
  95.  Float.cos : Float -> Float
  96.  Float.cosh : Float -> Float
  97.  Float.eq : Float -> Float -> Boolean
  98.  Float.exp : Float -> Float
  99.  Float.floor : Float -> Int
  100. Float.fromRepresentation : Nat -> Float
  101. Float.fromText : Text -> Optional Float
  102. Float.gt : Float -> Float -> Boolean
  103. Float.gteq : Float -> Float -> Boolean
  104. Float.log : Float -> Float
  105. Float.logBase : Float -> Float -> Float
  106. Float.lt : Float -> Float -> Boolean
  107. Float.lteq : Float -> Float -> Boolean
  108. Float.max : Float -> Float -> Float
  109. Float.min : Float -> Float -> Float
  110. Float.pow : Float -> Float -> Float
  111. Float.round : Float -> Int
  112. Float.sin : Float -> Float
  113. Float.sinh : Float -> Float
  114. Float.sqrt : Float -> Float
  115. Float.tan : Float -> Float
  116. Float.tanh : Float -> Float
  117. Float.toRepresentation : Float -> Nat
  118. Float.toText : Float -> Text
  119. Float.truncate : Float -> Int
  120. Handle.toText : Handle -> Text
  121. builtin type ImmutableArray
  122. ImmutableArray.copyTo! : MutableArray g a
                                -> Nat
                                -> ImmutableArray a
                                -> Nat
                                -> Nat
                                ->{g, Exception} ()
  123. ImmutableArray.read : ImmutableArray a
                             -> Nat
                             ->{Exception} a
  124. ImmutableArray.size : ImmutableArray a -> Nat
  125. builtin type ImmutableByteArray
  126. ImmutableByteArray.copyTo! : MutableByteArray g
                                    -> Nat
                                    -> ImmutableByteArray
                                    -> Nat
                                    -> Nat
                                    ->{g, Exception} ()
  127. ImmutableByteArray.read16be : ImmutableByteArray
                                     -> Nat
                                     ->{Exception} Nat
  128. ImmutableByteArray.read24be : ImmutableByteArray
                                     -> Nat
                                     ->{Exception} Nat
  129. ImmutableByteArray.read32be : ImmutableByteArray
                                     -> Nat
                                     ->{Exception} Nat
  130. ImmutableByteArray.read40be : ImmutableByteArray
                                     -> Nat
                                     ->{Exception} Nat
  131. ImmutableByteArray.read64be : ImmutableByteArray
                                     -> Nat
                                     ->{Exception} Nat
  132. ImmutableByteArray.read8 : ImmutableByteArray
                                  -> Nat
                                  ->{Exception} Nat
  133. ImmutableByteArray.size : ImmutableByteArray -> Nat
  134. builtin type Int
  135. Int.* : Int -> Int -> Int
  136. Int.+ : Int -> Int -> Int
  137. Int.- : Int -> Int -> Int
  138. Int./ : Int -> Int -> Int
  139. Int.and : Int -> Int -> Int
  140. Int.complement : Int -> Int
  141. Int.eq : Int -> Int -> Boolean
  142. Int.fromRepresentation : Nat -> Int
  143. Int.fromText : Text -> Optional Int
  144. Int.gt : Int -> Int -> Boolean
  145. Int.gteq : Int -> Int -> Boolean
  146. Int.increment : Int -> Int
  147. Int.isEven : Int -> Boolean
  148. Int.isOdd : Int -> Boolean
  149. Int.leadingZeros : Int -> Nat
  150. Int.lt : Int -> Int -> Boolean
  151. Int.lteq : Int -> Int -> Boolean
  152. Int.mod : Int -> Int -> Int
  153. Int.negate : Int -> Int
  154. Int.or : Int -> Int -> Int
  155. Int.popCount : Int -> Nat
  156. Int.pow : Int -> Nat -> Int
  157. Int.shiftLeft : Int -> Nat -> Int
  158. Int.shiftRight : Int -> Nat -> Int
  159. Int.signum : Int -> Int
  160. Int.toFloat : Int -> Float
  161. Int.toRepresentation : Int -> Nat
  162. Int.toText : Int -> Text
  163. Int.trailingZeros : Int -> Nat
  164. Int.truncate0 : Int -> Nat
  165. Int.xor : Int -> Int -> Int
  166. unique type io2.ArithmeticFailure
  167. unique type io2.ArrayFailure
  168. unique type io2.BufferMode
  169. io2.BufferMode.BlockBuffering : BufferMode
  170. io2.BufferMode.LineBuffering : BufferMode
  171. io2.BufferMode.NoBuffering : BufferMode
  172. io2.BufferMode.SizedBlockBuffering : Nat -> BufferMode
  173. io2.Clock.internals.monotonic : '{IO} Either
                                         Failure TimeSpec
  174. io2.Clock.internals.nsec : TimeSpec -> Nat
  175. io2.Clock.internals.processCPUTime : '{IO} Either
                                              Failure TimeSpec
  176. io2.Clock.internals.realtime : '{IO} Either
                                        Failure TimeSpec
  177. io2.Clock.internals.sec : TimeSpec -> Int
  178. io2.Clock.internals.threadCPUTime : '{IO} Either
                                             Failure TimeSpec
  179. builtin type io2.Clock.internals.TimeSpec
  180. unique type io2.Failure
  181. io2.Failure.Failure : Type -> Text -> Any -> Failure
  182. unique type io2.FileMode
  183. io2.FileMode.Append : FileMode
  184. io2.FileMode.Read : FileMode
  185. io2.FileMode.ReadWrite : FileMode
  186. io2.FileMode.Write : FileMode
  187. builtin type io2.Handle
  188. builtin type io2.IO
  189. io2.IO.array : Nat ->{IO} MutableArray {IO} a
  190. io2.IO.arrayOf : a -> Nat ->{IO} MutableArray {IO} a
  191. io2.IO.bytearray : Nat ->{IO} MutableByteArray {IO}
  192. io2.IO.bytearrayOf : Nat
                            -> Nat
                            ->{IO} MutableByteArray {IO}
  193. io2.IO.clientSocket.impl : Text
                                  -> Text
                                  ->{IO} Either Failure Socket
  194. io2.IO.closeFile.impl : Handle ->{IO} Either Failure ()
  195. io2.IO.closeSocket.impl : Socket ->{IO} Either Failure ()
  196. io2.IO.createDirectory.impl : Text
                                     ->{IO} Either Failure ()
  197. io2.IO.createTempDirectory.impl : Text
                                         ->{IO} Either
                                           Failure Text
  198. io2.IO.delay.impl : Nat ->{IO} Either Failure ()
  199. io2.IO.directoryContents.impl : Text
                                       ->{IO} Either
                                         Failure [Text]
  200. io2.IO.fileExists.impl : Text
                                ->{IO} Either Failure Boolean
  201. io2.IO.forkComp : '{IO} a ->{IO} ThreadId
  202. io2.IO.getArgs.impl : '{IO} Either Failure [Text]
  203. io2.IO.getBuffering.impl : Handle
                                  ->{IO} Either
                                    Failure BufferMode
  204. io2.IO.getBytes.impl : Handle
                              -> Nat
                              ->{IO} Either Failure Bytes
  205. io2.IO.getCurrentDirectory.impl : '{IO} Either
                                           Failure Text
  206. io2.IO.getEnv.impl : Text ->{IO} Either Failure Text
  207. io2.IO.getFileSize.impl : Text ->{IO} Either Failure Nat
  208. io2.IO.getFileTimestamp.impl : Text
                                      ->{IO} Either Failure Nat
  209. io2.IO.getLine.impl : Handle ->{IO} Either Failure Text
  210. io2.IO.getSomeBytes.impl : Handle
                                  -> Nat
                                  ->{IO} Either Failure Bytes
  211. io2.IO.getTempDirectory.impl : '{IO} Either Failure Text
  212. io2.IO.handlePosition.impl : Handle
                                    ->{IO} Either Failure Nat
  213. io2.IO.isDirectory.impl : Text
                                 ->{IO} Either Failure Boolean
  214. io2.IO.isFileEOF.impl : Handle
                               ->{IO} Either Failure Boolean
  215. io2.IO.isFileOpen.impl : Handle
                                ->{IO} Either Failure Boolean
  216. io2.IO.isSeekable.impl : Handle
                                ->{IO} Either Failure Boolean
  217. io2.IO.kill.impl : ThreadId ->{IO} Either Failure ()
  218. io2.IO.listen.impl : Socket ->{IO} Either Failure ()
  219. io2.IO.openFile.impl : Text
                              -> FileMode
                              ->{IO} Either Failure Handle
  220. io2.IO.putBytes.impl : Handle
                              -> Bytes
                              ->{IO} Either Failure ()
  221. io2.IO.ref : a ->{IO} Ref {IO} a
  222. io2.IO.removeDirectory.impl : Text
                                     ->{IO} Either Failure ()
  223. io2.IO.removeFile.impl : Text ->{IO} Either Failure ()
  224. io2.IO.renameDirectory.impl : Text
                                     -> Text
                                     ->{IO} Either Failure ()
  225. io2.IO.renameFile.impl : Text
                                -> Text
                                ->{IO} Either Failure ()
  226. io2.IO.seekHandle.impl : Handle
                                -> SeekMode
                                -> Int
                                ->{IO} Either Failure ()
  227. io2.IO.serverSocket.impl : Optional Text
                                  -> Text
                                  ->{IO} Either Failure Socket
  228. io2.IO.setBuffering.impl : Handle
                                  -> BufferMode
                                  ->{IO} Either Failure ()
  229. io2.IO.setCurrentDirectory.impl : Text
                                         ->{IO} Either
                                           Failure ()
  230. io2.IO.socketAccept.impl : Socket
                                  ->{IO} Either Failure Socket
  231. io2.IO.socketPort.impl : Socket ->{IO} Either Failure Nat
  232. io2.IO.socketReceive.impl : Socket
                                   -> Nat
                                   ->{IO} Either Failure Bytes
  233. io2.IO.socketSend.impl : Socket
                                -> Bytes
                                ->{IO} Either Failure ()
  234. io2.IO.stdHandle : StdHandle -> Handle
  235. io2.IO.systemTime.impl : '{IO} Either Failure Nat
  236. io2.IO.systemTimeMicroseconds : '{IO} Int
  237. io2.IO.tryEval : '{IO} a ->{IO, Exception} a
  238. unique type io2.IOError
  239. io2.IOError.AlreadyExists : IOError
  240. io2.IOError.EOF : IOError
  241. io2.IOError.IllegalOperation : IOError
  242. io2.IOError.NoSuchThing : IOError
  243. io2.IOError.PermissionDenied : IOError
  244. io2.IOError.ResourceBusy : IOError
  245. io2.IOError.ResourceExhausted : IOError
  246. io2.IOError.UserError : IOError
  247. unique type io2.IOFailure
  248. unique type io2.MiscFailure
  249. builtin type io2.MVar
  250. io2.MVar.isEmpty : MVar a ->{IO} Boolean
  251. io2.MVar.new : a ->{IO} MVar a
  252. io2.MVar.newEmpty : '{IO} MVar a
  253. io2.MVar.put.impl : MVar a -> a ->{IO} Either Failure ()
  254. io2.MVar.read.impl : MVar a ->{IO} Either Failure a
  255. io2.MVar.swap.impl : MVar a -> a ->{IO} Either Failure a
  256. io2.MVar.take.impl : MVar a ->{IO} Either Failure a
  257. io2.MVar.tryPut.impl : MVar a
                              -> a
                              ->{IO} Either Failure Boolean
  258. io2.MVar.tryRead.impl : MVar a
                               ->{IO} Either
                                 Failure (Optional a)
  259. io2.MVar.tryTake : MVar a ->{IO} Optional a
  260. unique type io2.RuntimeFailure
  261. unique type io2.SeekMode
  262. io2.SeekMode.AbsoluteSeek : SeekMode
  263. io2.SeekMode.RelativeSeek : SeekMode
  264. io2.SeekMode.SeekFromEnd : SeekMode
  265. builtin type io2.Socket
  266. unique type io2.StdHandle
  267. io2.StdHandle.StdErr : StdHandle
  268. io2.StdHandle.StdIn : StdHandle
  269. io2.StdHandle.StdOut : StdHandle
  270. builtin type io2.STM
  271. io2.STM.atomically : '{STM} a ->{IO} a
  272. io2.STM.retry : '{STM} a
  273. unique type io2.STMFailure
  274. builtin type io2.ThreadId
  275. builtin type io2.Tls
  276. builtin type io2.Tls.Cipher
  277. builtin type io2.Tls.ClientConfig
  278. io2.Tls.ClientConfig.certificates.set : [SignedCert]
                                               -> ClientConfig
                                               -> ClientConfig
  279. io2.TLS.ClientConfig.ciphers.set : [Cipher]
                                          -> ClientConfig
                                          -> ClientConfig
  280. io2.Tls.ClientConfig.default : Text
                                      -> Bytes
                                      -> ClientConfig
  281. io2.Tls.ClientConfig.versions.set : [Version]
                                           -> ClientConfig
                                           -> ClientConfig
  282. io2.Tls.decodeCert.impl : Bytes
                                 -> Either Failure SignedCert
  283. io2.Tls.decodePrivateKey : Bytes -> [PrivateKey]
  284. io2.Tls.encodeCert : SignedCert -> Bytes
  285. io2.Tls.encodePrivateKey : PrivateKey -> Bytes
  286. io2.Tls.handshake.impl : Tls ->{IO} Either Failure ()
  287. io2.Tls.newClient.impl : ClientConfig
                                -> Socket
                                ->{IO} Either Failure Tls
  288. io2.Tls.newServer.impl : ServerConfig
                                -> Socket
                                ->{IO} Either Failure Tls
  289. builtin type io2.Tls.PrivateKey
  290. io2.Tls.receive.impl : Tls ->{IO} Either Failure Bytes
  291. io2.Tls.send.impl : Tls -> Bytes ->{IO} Either Failure ()
  292. builtin type io2.Tls.ServerConfig
  293. io2.Tls.ServerConfig.certificates.set : [SignedCert]
                                               -> ServerConfig
                                               -> ServerConfig
  294. io2.Tls.ServerConfig.ciphers.set : [Cipher]
                                          -> ServerConfig
                                          -> ServerConfig
  295. io2.Tls.ServerConfig.default : [SignedCert]
                                      -> PrivateKey
                                      -> ServerConfig
  296. io2.Tls.ServerConfig.versions.set : [Version]
                                           -> ServerConfig
                                           -> ServerConfig
  297. builtin type io2.Tls.SignedCert
  298. io2.Tls.terminate.impl : Tls ->{IO} Either Failure ()
  299. builtin type io2.Tls.Version
  300. unique type io2.TlsFailure
  301. builtin type io2.TVar
  302. io2.TVar.new : a ->{STM} TVar a
  303. io2.TVar.newIO : a ->{IO} TVar a
  304. io2.TVar.read : TVar a ->{STM} a
  305. io2.TVar.readIO : TVar a ->{IO} a
  306. io2.TVar.swap : TVar a -> a ->{STM} a
  307. io2.TVar.write : TVar a -> a ->{STM} ()
  308. io2.validateSandboxed : [Term] -> a -> Boolean
  309. unique type IsPropagated
  310. IsPropagated.IsPropagated : IsPropagated
  311. unique type IsTest
  312. IsTest.IsTest : IsTest
  313. unique type Link
  314. builtin type Link.Term
  315. Link.Term : Term -> Link
  316. Link.Term.toText : Term -> Text
  317. builtin type Link.Type
  318. Link.Type : Type -> Link
  319. builtin type List
  320. List.++ : [a] -> [a] -> [a]
  321. List.+: : a -> [a] -> [a]
  322. List.:+ : [a] -> a -> [a]
  323. List.at : Nat -> [a] -> Optional a
  324. List.cons : a -> [a] -> [a]
  325. List.drop : Nat -> [a] -> [a]
  326. List.empty : [a]
  327. List.size : [a] -> Nat
  328. List.snoc : [a] -> a -> [a]
  329. List.take : Nat -> [a] -> [a]
  330. metadata.isPropagated : IsPropagated
  331. metadata.isTest : IsTest
  332. builtin type MutableArray
  333. MutableArray.copyTo! : MutableArray g a
                              -> Nat
                              -> MutableArray g a
                              -> Nat
                              -> Nat
                              ->{g, Exception} ()
  334. MutableArray.freeze : MutableArray g a
                             -> Nat
                             -> Nat
                             ->{g} ImmutableArray a
  335. MutableArray.freeze! : MutableArray g a
                              ->{g} ImmutableArray a
  336. MutableArray.read : MutableArray g a
                           -> Nat
                           ->{g, Exception} a
  337. MutableArray.size : MutableArray g a -> Nat
  338. MutableArray.write : MutableArray g a
                            -> Nat
                            -> a
                            ->{g, Exception} ()
  339. builtin type MutableByteArray
  340. MutableByteArray.copyTo! : MutableByteArray g
                                  -> Nat
                                  -> MutableByteArray g
                                  -> Nat
                                  -> Nat
                                  ->{g, Exception} ()
  341. MutableByteArray.freeze : MutableByteArray g
                                 -> Nat
                                 -> Nat
                                 ->{g} ImmutableByteArray
  342. MutableByteArray.freeze! : MutableByteArray g
                                  ->{g} ImmutableByteArray
  343. MutableByteArray.read16be : MutableByteArray g
                                   -> Nat
                                   ->{g, Exception} Nat
  344. MutableByteArray.read24be : MutableByteArray g
                                   -> Nat
                                   ->{g, Exception} Nat
  345. MutableByteArray.read32be : MutableByteArray g
                                   -> Nat
                                   ->{g, Exception} Nat
  346. MutableByteArray.read40be : MutableByteArray g
                                   -> Nat
                                   ->{g, Exception} Nat
  347. MutableByteArray.read64be : MutableByteArray g
                                   -> Nat
                                   ->{g, Exception} Nat
  348. MutableByteArray.read8 : MutableByteArray g
                                -> Nat
                                ->{g, Exception} Nat
  349. MutableByteArray.size : MutableByteArray g -> Nat
  350. MutableByteArray.write16be : MutableByteArray g
                                    -> Nat
                                    -> Nat
                                    ->{g, Exception} ()
  351. MutableByteArray.write32be : MutableByteArray g
                                    -> Nat
                                    -> Nat
                                    ->{g, Exception} ()
  352. MutableByteArray.write64be : MutableByteArray g
                                    -> Nat
                                    -> Nat
                                    ->{g, Exception} ()
  353. MutableByteArray.write8 : MutableByteArray g
                                 -> Nat
                                 -> Nat
                                 ->{g, Exception} ()
  354. builtin type Nat
  355. Nat.* : Nat -> Nat -> Nat
  356. Nat.+ : Nat -> Nat -> Nat
  357. Nat./ : Nat -> Nat -> Nat
  358. Nat.and : Nat -> Nat -> Nat
  359. Nat.complement : Nat -> Nat
  360. Nat.drop : Nat -> Nat -> Nat
  361. Nat.eq : Nat -> Nat -> Boolean
  362. Nat.fromText : Text -> Optional Nat
  363. Nat.gt : Nat -> Nat -> Boolean
  364. Nat.gteq : Nat -> Nat -> Boolean
  365. Nat.increment : Nat -> Nat
  366. Nat.isEven : Nat -> Boolean
  367. Nat.isOdd : Nat -> Boolean
  368. Nat.leadingZeros : Nat -> Nat
  369. Nat.lt : Nat -> Nat -> Boolean
  370. Nat.lteq : Nat -> Nat -> Boolean
  371. Nat.mod : Nat -> Nat -> Nat
  372. Nat.or : Nat -> Nat -> Nat
  373. Nat.popCount : Nat -> Nat
  374. Nat.pow : Nat -> Nat -> Nat
  375. Nat.shiftLeft : Nat -> Nat -> Nat
  376. Nat.shiftRight : Nat -> Nat -> Nat
  377. Nat.sub : Nat -> Nat -> Int
  378. Nat.toFloat : Nat -> Float
  379. Nat.toInt : Nat -> Int
  380. Nat.toText : Nat -> Text
  381. Nat.trailingZeros : Nat -> Nat
  382. Nat.xor : Nat -> Nat -> Nat
  383. structural type Optional a
  384. Optional.None : Optional a
  385. Optional.Some : a -> Optional a
  386. builtin type Pattern
  387. Pattern.capture : Pattern a -> Pattern a
  388. Pattern.isMatch : Pattern a -> a -> Boolean
  389. Pattern.join : [Pattern a] -> Pattern a
  390. Pattern.many : Pattern a -> Pattern a
  391. Pattern.or : Pattern a -> Pattern a -> Pattern a
  392. Pattern.replicate : Nat -> Nat -> Pattern a -> Pattern a
  393. Pattern.run : Pattern a -> a -> Optional ([a], a)
  394. builtin type Ref
  395. Ref.read : Ref g a ->{g} a
  396. Ref.write : Ref g a -> a ->{g} ()
  397. builtin type Request
  398. builtin type Scope
  399. Scope.array : Nat ->{Scope s} MutableArray (Scope s) a
  400. Scope.arrayOf : a
                       -> Nat
                       ->{Scope s} MutableArray (Scope s) a
  401. Scope.bytearray : Nat
                         ->{Scope s} MutableByteArray (Scope s)
  402. Scope.bytearrayOf : Nat
                           -> Nat
                           ->{Scope s} MutableByteArray
                             (Scope s)
  403. Scope.ref : a ->{Scope s} Ref {Scope s} a
  404. Scope.run : (∀ s. '{g, Scope s} r) ->{g} r
  405. structural type SeqView a b
  406. SeqView.VElem : a -> b -> SeqView a b
  407. SeqView.VEmpty : SeqView a b
  408. Socket.toText : Socket -> Text
  409. unique type Test.Result
  410. Test.Result.Fail : Text -> Result
  411. Test.Result.Ok : Text -> Result
  412. builtin type Text
  413. Text.!= : Text -> Text -> Boolean
  414. Text.++ : Text -> Text -> Text
  415. Text.drop : Nat -> Text -> Text
  416. Text.empty : Text
  417. Text.eq : Text -> Text -> Boolean
  418. Text.fromCharList : [Char] -> Text
  419. Text.fromUtf8.impl : Bytes -> Either Failure Text
  420. Text.gt : Text -> Text -> Boolean
  421. Text.gteq : Text -> Text -> Boolean
  422. Text.lt : Text -> Text -> Boolean
  423. Text.lteq : Text -> Text -> Boolean
  424. Text.patterns.anyChar : Pattern Text
  425. Text.patterns.charIn : [Char] -> Pattern Text
  426. Text.patterns.charRange : Char -> Char -> Pattern Text
  427. Text.patterns.digit : Pattern Text
  428. Text.patterns.eof : Pattern Text
  429. Text.patterns.letter : Pattern Text
  430. Text.patterns.literal : Text -> Pattern Text
  431. Text.patterns.notCharIn : [Char] -> Pattern Text
  432. Text.patterns.notCharRange : Char -> Char -> Pattern Text
  433. Text.patterns.punctuation : Pattern Text
  434. Text.patterns.space : Pattern Text
  435. Text.repeat : Nat -> Text -> Text
  436. Text.reverse : Text -> Text
  437. Text.size : Text -> Nat
  438. Text.take : Nat -> Text -> Text
  439. Text.toCharList : Text -> [Char]
  440. Text.toLowercase : Text -> Text
  441. Text.toUppercase : Text -> Text
  442. Text.toUtf8 : Text -> Bytes
  443. Text.uncons : Text -> Optional (Char, Text)
  444. Text.unsnoc : Text -> Optional (Text, Char)
  445. ThreadId.toText : ThreadId -> Text
  446. todo : a -> b
  447. structural type Tuple a b
  448. Tuple.Cons : a -> b -> Tuple a b
  449. structural type Unit
  450. Unit.Unit : ()
  451. Universal.< : a -> a -> Boolean
  452. Universal.<= : a -> a -> Boolean
  453. Universal.== : a -> a -> Boolean
  454. Universal.> : a -> a -> Boolean
  455. Universal.>= : a -> a -> Boolean
  456. Universal.compare : a -> a -> Int
  457. unsafe.coerceAbilities : (a ->{e1} b) -> a ->{e2} b
  458. builtin type Value
  459. Value.dependencies : Value -> [Term]
  460. Value.deserialize : Bytes -> Either Text Value
  461. Value.load : Value ->{IO} Either [Term] a
  462. Value.serialize : Value -> Bytes
  463. Value.value : a -> Value
  

.builtin> alias.many 94-104 .mylib

  Here's what changed in .mylib :
  
  Added definitions:
  
    1.  Float.ceiling            : Float -> Int
    2.  Float.cos                : Float -> Float
    3.  Float.cosh               : Float -> Float
    4.  Float.eq                 : Float -> Float -> Boolean
    5.  Float.exp                : Float -> Float
    6.  Float.floor              : Float -> Int
    7.  Float.fromRepresentation : Nat -> Float
    8.  Float.fromText           : Text -> Optional Float
    9.  Float.gt                 : Float -> Float -> Boolean
    10. Float.gteq               : Float -> Float -> Boolean
    11. Float.log                : Float -> Float
  
  Tip: You can use `undo` or `reflog` to undo this change.

```
I want to incorporate a few more from another namespace:
```ucm
.builtin> cd .runar

.runar> find

  1.  List.adjacentPairs : [a] -> [(a, a)]
  2.  List.all : (a ->{g} Boolean) -> [a] ->{g} Boolean
  3.  List.any : (a ->{g} Boolean) -> [a] ->{g} Boolean
  4.  List.chunk : Nat -> [a] -> [[a]]
  5.  List.chunksOf : Nat -> [a] -> [[a]]
  6.  List.dropWhile : (a ->{g} Boolean) -> [a] ->{g} [a]
  7.  List.first : [a] -> Optional a
  8.  List.init : [a] -> Optional [a]
  9.  List.intersperse : a -> [a] -> [a]
  10. List.isEmpty : [a] -> Boolean
  11. List.last : [a] -> Optional a
  12. List.replicate : Nat -> a -> [a]
  13. List.splitAt : Nat -> [a] -> ([a], [a])
  14. List.tail : [a] -> Optional [a]
  15. List.takeWhile : (a ->{𝕖} Boolean) -> [a] ->{𝕖} [a]
  

.runar> alias.many 1-15 .mylib

  Here's what changed in .mylib :
  
  Added definitions:
  
    1.  List.adjacentPairs : [a] -> [(a, a)]
    2.  List.all           : (a ->{g} Boolean)
                           -> [a]
                           ->{g} Boolean
    3.  List.any           : (a ->{g} Boolean)
                           -> [a]
                           ->{g} Boolean
    4.  List.chunk         : Nat -> [a] -> [[a]]
    5.  List.chunksOf      : Nat -> [a] -> [[a]]
    6.  List.dropWhile     : (a ->{g} Boolean) -> [a] ->{g} [a]
    7.  List.first         : [a] -> Optional a
    8.  List.init          : [a] -> Optional [a]
    9.  List.intersperse   : a -> [a] -> [a]
    10. List.isEmpty       : [a] -> Boolean
    11. List.last          : [a] -> Optional a
    12. List.replicate     : Nat -> a -> [a]
    13. List.splitAt       : Nat -> [a] -> ([a], [a])
    14. List.tail          : [a] -> Optional [a]
    15. List.takeWhile     : (a ->{𝕖} Boolean) -> [a] ->{𝕖} [a]
  
  Tip: You can use `undo` or `reflog` to undo this change.

.runar> cd .mylib

.mylib> find

  1.  Float.ceiling : Float -> Int
  2.  Float.cos : Float -> Float
  3.  Float.cosh : Float -> Float
  4.  Float.eq : Float -> Float -> Boolean
  5.  Float.exp : Float -> Float
  6.  Float.floor : Float -> Int
  7.  Float.fromRepresentation : Nat -> Float
  8.  Float.fromText : Text -> Optional Float
  9.  Float.gt : Float -> Float -> Boolean
  10. Float.gteq : Float -> Float -> Boolean
  11. Float.log : Float -> Float
  12. List.adjacentPairs : [a] -> [(a, a)]
  13. List.all : (a ->{g} Boolean) -> [a] ->{g} Boolean
  14. List.any : (a ->{g} Boolean) -> [a] ->{g} Boolean
  15. List.chunk : Nat -> [a] -> [[a]]
  16. List.chunksOf : Nat -> [a] -> [[a]]
  17. List.dropWhile : (a ->{g} Boolean) -> [a] ->{g} [a]
  18. List.first : [a] -> Optional a
  19. List.init : [a] -> Optional [a]
  20. List.intersperse : a -> [a] -> [a]
  21. List.isEmpty : [a] -> Boolean
  22. List.last : [a] -> Optional a
  23. List.replicate : Nat -> a -> [a]
  24. List.splitAt : Nat -> [a] -> ([a], [a])
  25. List.tail : [a] -> Optional [a]
  26. List.takeWhile : (a ->{𝕖} Boolean) -> [a] ->{𝕖} [a]
  

```
Thanks, `alias.many!
