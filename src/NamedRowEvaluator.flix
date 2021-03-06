/*
 * Copyright 2020 Stephen Tetley
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */




namespace SheetIO {

    pub opaque type NamedRowEvaluator[a] = (Map[String, Int32], ##org.apache.poi.ss.usermodel.DataFormatter, ##org.apache.poi.ss.usermodel.Row) ~> Result[a, String]

}

namespace SheetIO/NamedRowEvaluator {

    use SheetIO.NamedRowEvaluator;
    use SheetIO.NamedRowEvaluator.{NamedRowEvaluator};

    use SheetIO.CellType;
    use SheetIO.CellType.{TyNone, TyBlank, TyBoolean, TyError, TyFormula, TyNumeric, TyString};
    use SheetIO.DataFormatter;
    use SheetIO.DataFormatter.{DataFormatter};


    pub def makeHeaders(names: Array[String]): Map[String, Int32] & Impure =
        let step = (acc, x) -> { let (i, mx) = acc; (i + 1, Map.insert(x, i, mx)) };
        Array.foldLeft(step, (0, Map.empty()), names) |> snd


    pub def return(x: a): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, _) -> Ok(x) as & Impure)

    def apply1(x: NamedRowEvaluator[a], 
               ixs: Map[String, Int32], 
               fmt: ##org.apache.poi.ss.usermodel.DataFormatter,
               row: ##org.apache.poi.ss.usermodel.Row): Result[a, String] & Impure =
        let NamedRowEvaluator(f) = x;
        f(ixs, fmt, row)

    pub def throwError(msg: String): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, _) -> Err(msg) as & Impure)

    /// TODO - row num is useful but we need a less ad-hoc API...
    pub def throwErrorWithRowNum(msgF: Int32 -> String): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, row) -> 
            let msg = msgF(SheetIO/Internal/Row.getRowNum(row));
            Err(msg)
        )


    pub def swapError(ma: NamedRowEvaluator[a], msg: String): NamedRowEvaluator[a] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(ma, ixs, fmt, row) {
                case Ok(a) => Ok(a)
                case Err(_) => Err(msg)
            }
        )

    /// TODO - row num is useful but we need a less ad-hoc API...
    pub def swapErrorWithRowNum(ma: NamedRowEvaluator[a], msgF: Int32 -> String): NamedRowEvaluator[a] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(ma, ixs, fmt, row) {
                case Ok(a) => Ok(a)
                case Err(_) => { 
                    let msg = msgF(SheetIO/Internal/Row.getRowNum(row));
                    Err(msg)
                }
            }
        )


    pub def map(f: a -> b & ef, x: NamedRowEvaluator[a]): NamedRowEvaluator[b] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(x, ixs, fmt, row) {
                case Ok(a) => {
                    let ans = f(a) as & Impure;
                    Ok(ans)
                }
                case Err(e) => Err(e)
            }
        )

    pub def ap(mf: NamedRowEvaluator[a -> b & ef], ma: NamedRowEvaluator[a]): NamedRowEvaluator[b] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(mf, ixs, fmt, row) {
                case Ok(f) => {
                    match apply1(ma, ixs, fmt, row) {
                        case Ok(a) => Ok(f(a) as & Impure)
                        case Err(e2) => Err(e2)
                    }
                }
                case Err(e1) => Err(e1)
            }
        )
    
    pub def seqLeft(ma: NamedRowEvaluator[a], mb: NamedRowEvaluator[b]): NamedRowEvaluator[a] = 
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(ma, ixs, fmt, row) { 
                case Ok(a) => match apply1(mb, ixs, fmt, row) {
                    case Ok(_) => Ok(a)
                    case Err(e) => Err(e)
                }
                case Err(e) => Err(e)
            }
        )

    pub def seqRight(ma: NamedRowEvaluator[a], mb: NamedRowEvaluator[b]): NamedRowEvaluator[b] = 
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(ma, ixs, fmt, row) { 
                case Ok(_) => apply1(mb, ixs, fmt, row)
                case Err(e) => Err(e)
            }
        )

    pub def bind(x: NamedRowEvaluator[a], k: a -> NamedRowEvaluator[b]): NamedRowEvaluator[b] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(x, ixs, fmt, row) {
                case Ok(a) => { let ans = k(a); apply1(ans, ixs, fmt, row) }
                case Err(e) => Err(e)
            }
        )

    pub def flatMap(k: a -> NamedRowEvaluator[b], x: NamedRowEvaluator[a]): NamedRowEvaluator[b] = bind(x, k)

    pub def kleisliLeft(f1: a -> NamedRowEvaluator[b], f2: b -> NamedRowEvaluator[c], x: a): NamedRowEvaluator[c] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(f1(x), ixs, fmt, row) { 
                case Ok(b) => apply1(f2(b), ixs, fmt, row)
                case Err(e) => Err(e)
            }
        )

    pub def kleisliRight(f1: b -> NamedRowEvaluator[c], f2: a -> NamedRowEvaluator[b], x: a): NamedRowEvaluator[c] =
        kleisliLeft(f2, f1, x)

    pub def optional(x: NamedRowEvaluator[a]): NamedRowEvaluator[Option[a]] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(x, ixs, fmt, row) {
                case Ok(a) => Ok(Some(a))
                case Err(_) => Ok(None)
            }
        )

    /// Note - this returns default for all errors (i.e. unknown column which is a
    /// schema error). Might be better if it can just return default if cell is null...
    pub def withDefault(x: NamedRowEvaluator[a], d: a): NamedRowEvaluator[a] =
        alt(x, return(d))

    pub def alt(ea: NamedRowEvaluator[a], eb: NamedRowEvaluator[a]): NamedRowEvaluator[a] =
        NamedRowEvaluator((ixs, fmt, row) ->
            match apply1(ea, ixs, fmt, row) {
                case Ok(a) => Ok(a)
                case Err(_) => apply1(eb, ixs, fmt, row) 
            }
        )


    pub def mapM(mf: a -> NamedRowEvaluator[b], xs: List[a]): NamedRowEvaluator[List[b]] =
        NamedRowEvaluator((ixs, fmt, row) ->
            mapMHelper(ixs, fmt, row, mf, xs, e -> Err(e), ys -> Ok(ys))
        )

    ///
    /// Helper function for `mapM`.
    ///
    def mapMHelper(ixs: Map[String, Int32], 
                   fmt: ##org.apache.poi.ss.usermodel.DataFormatter, 
                   row: ##org.apache.poi.ss.usermodel.Row, 
                   mf: a -> NamedRowEvaluator[b], 
                   xs: List[a], 
                   fk: String -> Result[List[b], String], 
                   sk: List[b] -> Result[List[b], String]): Result[List[b], String] & Impure =
        match xs {
            case Nil => sk(Nil)
            case x :: rs => {
                let ma = mf(x);
                match apply1(ma, ixs, fmt, row) {
                    case Err(e) => fk(e)
                    case Ok(x1) => mapMHelper(ixs, fmt, row, mf, rs, fk, ks -> sk(x1 :: ks))
                }
            }
        }
        
        
    def liftPrim(ask: ##org.apache.poi.ss.usermodel.Row ~> Result[a, String]): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, row) -> ask(row))


    pub def liftAction(fn: Unit ~> a): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, _) -> let x = fn(); Ok(x))

    pub def liftActionResult(fn: Unit ~> Result[a, String]): NamedRowEvaluator[a] =
        NamedRowEvaluator((_, _, _) -> fn())

    pub def liftOption(x: Option[a], errMsg: String): NamedRowEvaluator[a] = match x { 
        case Some(x1) => return(x1)
        case None => throwError(errMsg)
    }

    pub def liftResult(x: Result[a, e], makeErrMsg: e -> String): NamedRowEvaluator[a] = match x { 
        case Ok(x1) => return(x1)
        case Err(e) => throwError(makeErrMsg(e))
    }

    pub def liftValidation(x: Validation[a, e], makeErrMsg: List[e] -> String): NamedRowEvaluator[a] = match x { 
        case Success(x1) => return(x1)
        case Failure(es) => throwError(makeErrMsg(Nel.toList(es)))
    }

    // // Note - the primitive setX! functions index from 1, we add 1 to calls
    // // so FactIO's API indexes from 0.
    
    def getIndex(label: String): NamedRowEvaluator[Int32] =
        NamedRowEvaluator((ixs, _, _) -> match Map.get(label, ixs) {
            case Some(ix) => Ok(ix) as & Impure
            case None => Err("getIndex - '${label}'") as & Impure
        })

    def getDataFormatter(): NamedRowEvaluator[##org.apache.poi.ss.usermodel.DataFormatter] =
        NamedRowEvaluator((_, fmt, _) -> Ok(fmt) as & Impure)


    def withCell(row: ##org.apache.poi.ss.usermodel.Row,
                 ix: Int32, 
                 f: ##org.apache.poi.ss.usermodel.Cell ~> Result[a, String]): Result[a, String] & Impure = 
        use Result.{flatMap};
        let* cell = SheetIO/Internal/Row.getCell(row, ix);
        f(cell)

    pub def getRowNum(): NamedRowEvaluator[Int32] = 
        NamedRowEvaluator((_, _, row) -> Ok(SheetIO/Internal/Row.getRowNum(row)))

    pub def getContentNamed(label: String): NamedRowEvaluator[String] =
        let* ix     = getIndex(label);
        let* fmt    = getDataFormatter();
        liftPrim(x -> withCell(x, ix, SheetIO/Internal/DataFormatter.formatCellValue(fmt))) `swapError` "getContentNamed('${label}')"


    /// Uses the default DataFormatter
    pub def getTrimmedContentNamed(label: String): NamedRowEvaluator[String] =
        map(String.trim, getContentNamed(label)) `swapError` "getTrimmedContentNamed(${label})"
        

    pub def isNullNamed(label: String): NamedRowEvaluator[Bool] = 
        let* ix     = getIndex(label);
        liftPrim(x -> withCell(x, ix, ans -> Ok(Object.isNull(ans) as & Impure)))

    pub def getNullNamed(label: String): NamedRowEvaluator[Unit] =
        let* ix     = getIndex(label);
        liftPrim(x -> withCell(x, ix, ans -> if (Object.isNull(ans)) (Ok() as & Impure) else Err("getNullNamed")))


    pub def getCellTypeNamed(label: String): NamedRowEvaluator[CellType] =
        let* ix     = getIndex(label);
        map(SheetIO/CellType.fromNative, liftPrim(x -> withCell(x, ix, SheetIO/Internal/Cell.getCellType)))

    pub def isBlankNamed(label: String): NamedRowEvaluator[Bool] = 
        let* typ = getCellTypeNamed(label);
        match typ { 
            case TyBlank => return(true)
            case _ => return(false)
        }


    pub def getBlankNamed(label: String): NamedRowEvaluator[Unit] = 
        let* typ = getCellTypeNamed(label);
        match typ { 
            case TyBlank => return()
            case _ => throwError("getBlankNamed($label}) - not blank")
        }
    
    pub def getStringNamed(label: String): NamedRowEvaluator[String] =
        let* ix     = getIndex(label);
        liftPrim(x -> withCell(x, ix, SheetIO/Internal/Cell.getStringCellValue)) `swapError` "getStringNamed('${label}')"
            


    pub def getSatifiesNamed(label: String, test: String -> Bool): NamedRowEvaluator[String] =
        let step = getContentNamed(label) >>= x -> 
                    if (test(x)) return(x) else throwError("getSatifiesNamed('${label}') - failed");
        step `swapError` "getSatifiesNamed('${label}')"


    pub def getNonEmptyContentNamed(label: String): NamedRowEvaluator[String] =
        getSatifiesNamed(label, x -> not String.isEmpty(x)) `swapError` "getNonEmptyContentNamed('${label}')"


    pub def getStringNamedWithDefault(label: String, d: String): NamedRowEvaluator[String] =
        let* x = isNullNamed(label);
        if (x) return(d) else getStringNamed(label)


    pub def getStringNamedWithDataFormatter(label: String, dfmt: DataFormatter): NamedRowEvaluator[String] =
        let* ix     = getIndex(label);
        let DataFormatter(dfmt1) = dfmt;
        liftPrim(x -> withCell(x, ix, cell -> SheetIO/Internal/DataFormatter.formatCellValue(dfmt1, cell)))


    pub def getBoolNamed(label: String): NamedRowEvaluator[Bool] =
        let* ix     = getIndex(label);
        liftPrim(x -> withCell(x, ix, SheetIO/Internal/Cell.getBooleanCellValue)) `swapError` "getNumericNamed('${label}')"
    

    pub def getNumericNamed(label: String): NamedRowEvaluator[Float64] =
        let* ix     = getIndex(label);
        liftPrim(x -> withCell(x, ix, SheetIO/Internal/Cell.getNumericCellValue)) `swapError` "getNumericNamed('${label}')"

    def getNumNamed(label: String, conv: Float64 -> Option[a], errMsg: String): NamedRowEvaluator[a] =
        let* n = getNumericNamed(label);
        liftOption(conv(n), errMsg)


    pub def getInt8Named(label: String): NamedRowEvaluator[Int8] =
        getNumNamed(label, Float64.tryToInt8, "getInt8Named('${label}')")

    pub def getInt16Named(label: String): NamedRowEvaluator[Int16] =
        getNumNamed(label, Float64.tryToInt16, "getInt16Named('${label}')")

    pub def getInt32Named(label: String): NamedRowEvaluator[Int32] =
        getNumNamed(label, Float64.tryToInt32, "getInt32Named('${label}')")

    pub def getInt64Named(label: String): NamedRowEvaluator[Int64] =
        getNumNamed(label, Float64.tryToInt64, "getInt64Named('${label}')")

    pub def getFloat32Named(label: String): NamedRowEvaluator[Float32] =
        getNumNamed(label, Float64.tryToFloat32, "getFloat32Named('${label}')")
    
    pub def getFloat64Named(label: String): NamedRowEvaluator[Float64] = 
        getNumNamed(label, x -> Some(x), "getFloat64Named('${label}')")

    /// Note will fail if CellType is String.
    pub def getLocalDateTimeNamed(label: String): NamedRowEvaluator[Time.LocalDateTime] = 
        use Time.LocalDateTime.{LocalDateTime};
        let* ix     = getIndex(label);
        let* dt1 = liftPrim(x -> withCell(x, ix, SheetIO/Internal/Cell.getLocalDateTimeCellValue));
        return(LocalDateTime(dt1))


    /// Cell must be readable as a String
    pub def getLocalDateTimeNamedWithFormat(label: String, fmt: Time/Format.DateTimeFormatter): NamedRowEvaluator[Time.LocalDateTime] = 
        let* s = getStringNamed(label);
        liftOption(Time/LocalDateTime.parse(s, fmt), "getLocalDateTimeNamedWithFormat - '${s}'")
        

    /// Cell must be readable as a String
    pub def getLocalTimeDateNamedWithPattern(label: String, patt: String): NamedRowEvaluator[Time.LocalDateTime] = 
        let* fmt    = liftOption(Time/Format/DateTimeFormatter.ofPattern(patt), "getLocalTimeDateNamedWithPattern - bad pattern");
        let* s      = getStringNamed(label);
        liftOption(Time/LocalDateTime.parse(s, fmt), "getLocalTimeDateNamedWithPattern - '${s}'")


    pub def getLocalDateNamed(label: String): NamedRowEvaluator[Time.LocalDate] = 
        map(Time/LocalDateTime.toLocalDate, getLocalDateTimeNamed(label)) `swapError` "getLocalDateNamed"

    /// Cell must be readable as a String
    pub def getLocalDateNamedWithFormat(label: String, fmt: Time/Format.DateFormatter): NamedRowEvaluator[Time.LocalDate] = 
        let* s = getStringNamed(label);
        liftOption(Time/LocalDate.parse(s, fmt), "getLocalDateNamedWithFormat - '${s}'")
        

    /// Cell must be readable as a String
    pub def getLocalDateNamedWithPattern(label: String, patt: String): NamedRowEvaluator[Time.LocalDate] = 
        let* fmt    = liftOption(Time/Format/DateFormatter.ofPattern(patt), "getLocalDateNamedWithPattern - bad pattern");
        let* s      = getStringNamed(label);
        liftOption(Time/LocalDate.parse(s, fmt), "getLocalDateNamedWithPattern - '${s}'")
    


    def getIfNotEmpty(label: String, getter: String -> NamedRowEvaluator[a]): NamedRowEvaluator[Option[a]] = 
        let* x1 = isNullNamed(label);
        let* y1 = isBlankNamed(label);
        if (x1 or y1) return(None) else map(Some, getter(label))

    pub def getOptionStringNamed(label: String): NamedRowEvaluator[Option[String]] =
        getIfNotEmpty(label, getStringNamed)



    pub def getOptionInt8Named(label: String): NamedRowEvaluator[Option[Int8]] =
        getIfNotEmpty(label, getInt8Named)

    pub def getOptionInt16Named(label: String): NamedRowEvaluator[Option[Int16]] =
        getIfNotEmpty(label, getInt16Named)

    pub def getOptionInt32Named(label: String): NamedRowEvaluator[Option[Int32]] =
        getIfNotEmpty(label, getInt32Named)

    pub def getOptionInt64Named(label: String): NamedRowEvaluator[Option[Int64]] =
        getIfNotEmpty(label, getInt64Named)

    pub def getOptionFloat32Named(label: String): NamedRowEvaluator[Option[Float32]] =
        getIfNotEmpty(label, getFloat32Named)
    
    pub def getOptionFloat64Named(label: String): NamedRowEvaluator[Option[Float64]] = 
        getIfNotEmpty(label, getFloat64Named) `swapErrorWithRowNum` (i -> "getOptionFloat64Named('${label}') - row: ${i}")

    pub def getOptionLocalDateTimeNamed(label: String): NamedRowEvaluator[Option[Time.LocalDateTime]] = 
        getIfNotEmpty(label, getLocalDateTimeNamed)




    def queryFontAt(ix: Int32, asks: ##org.apache.poi.ss.usermodel.Font ~> Result[a, String]): NamedRowEvaluator[a] = 
        use Result.flatMap;
        liftPrim(row -> 
            let* cell   = SheetIO/Internal/Row.getCell(row, ix);
            let* style  = SheetIO/Internal/Cell.getCellStyle(cell);
            let* idx    = SheetIO/Internal/CellStyle.getFontIndexAsInt(style);
            let* sheet  = SheetIO/Internal/Row.getSheet(row);
            let* wb     = SheetIO/Internal/Sheet.getWorkbook(sheet);
            let* font   = SheetIO/Internal/Workbook.getFontAt(wb, idx);
            let* ans    = asks(font); 
            Ok(ans)
        )


    pub def getIsBoldNamed(label: String): NamedRowEvaluator[Bool] = 
        let* ix = getIndex(label);
        queryFontAt(ix, SheetIO/Internal/Font.getBold)


    pub def getIsItalicNamed(label: String): NamedRowEvaluator[Bool] = 
        let* ix = getIndex(label);
        queryFontAt(ix, SheetIO/Internal/Font.getItalic)

    pub def getIsStrikeoutNamed(label: String): NamedRowEvaluator[Bool] = 
        let* ix = getIndex(label);
        queryFontAt(ix, SheetIO/Internal/Font.getStrikeout)



    ///
    /// Applies the binary function `f` to the values in `o1` and `o2`.
    ///
    /// Returns an error if either `o1` or `o2` are errors.
    ///
    pub def lift2(f: (t1, t2) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2]): NamedRowEvaluator[u] =
        ap(map(f, o1), o2)

    ///
    /// Applies the ternary function `f` to the values in `o1`, `o2` and `o3`.
    ///
    /// Returns an error if any of `o1`, `o2` and `o3` are errors.
    ///
    pub def lift3(f: (t1, t2, t3) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3]): NamedRowEvaluator[u] =
        ap(lift2(f, o1, o2), o3)

    ///
    /// Applies the 4-ary function `f` to the values in `o1`, `o2`, `o3` and `o4`.
    ///
    /// Returns an error if any of `o1`, `o2`, `o3` and `o4` are errors.
    ///
    pub def lift4(f: (t1, t2, t3, t4) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3], 
                  o4: NamedRowEvaluator[t4]): NamedRowEvaluator[u] =
        ap(lift3(f, o1, o2, o3), o4)

    ///
    /// Applies the 5-ary function `f` to the values in `o1`, `o2`, ... `o5`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o5` are errors.
    ///
    pub def lift5(f: (t1, t2, t3, t4, t5) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3], 
                  o4: NamedRowEvaluator[t4], 
                  o5: NamedRowEvaluator[t5]): NamedRowEvaluator[u] =
        ap(lift4(f, o1, o2, o3, o4), o5)

    ///
    /// Applies the 6-ary function `f` to the values in `o1`, `o2`, ... `o6`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o6` are errors.
    ///
    pub def lift6(f: (t1, t2, t3, t4, t5, t6) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3],
                  o4: NamedRowEvaluator[t4], 
                  o5: NamedRowEvaluator[t5], 
                  o6: NamedRowEvaluator[t6]): NamedRowEvaluator[u] =
        ap(lift5(f, o1, o2, o3, o4, o5), o6)

    ///
    /// Applies the 7-ary function `f` to the values in `o1`, `o2`, ... `o7`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o7` are errors.
    ///
    pub def lift7(f: (t1, t2, t3, t4, t5, t6, t7) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3], 
                  o4: NamedRowEvaluator[t4], 
                  o5: NamedRowEvaluator[t5], 
                  o6: NamedRowEvaluator[t6], 
                  o7: NamedRowEvaluator[t7]): NamedRowEvaluator[u] =
        ap(lift6(f, o1, o2, o3, o4, o5, o6), o7)

    ///
    /// Applies the 8-ary function `f` to the values in `o1`, `o2`, ... `o8`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o8` are errors.
    ///
    pub def lift8(f: (t1, t2, t3, t4, t5, t6, t7, t8) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3], 
                  o4: NamedRowEvaluator[t4], 
                  o5: NamedRowEvaluator[t5], 
                  o6: NamedRowEvaluator[t6], 
                  o7: NamedRowEvaluator[t7], 
                  o8: NamedRowEvaluator[t8]): NamedRowEvaluator[u] =
        ap(lift7(f, o1, o2, o3, o4, o5, o6, o7), o8)

    ///
    /// Applies the 9-ary function `f` to the values in `o1`, `o2`, ... `o9`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o9` are errors.
    ///
    pub def lift9(f: (t1, t2, t3, t4, t5, t6, t7, t8, t9) -> u & ef, 
                  o1: NamedRowEvaluator[t1], 
                  o2: NamedRowEvaluator[t2], 
                  o3: NamedRowEvaluator[t3], 
                  o4: NamedRowEvaluator[t4], 
                  o5: NamedRowEvaluator[t5], 
                  o6: NamedRowEvaluator[t6], 
                  o7: NamedRowEvaluator[t7], 
                  o8: NamedRowEvaluator[t8], 
                  o9: NamedRowEvaluator[t9]): NamedRowEvaluator[u] =
        ap(lift8(f, o1, o2, o3, o4, o5, o6, o7, o8), o9)

    ///
    /// Applies the 10-ary function `f` to the values in `o1`, `o2`, ... `o10`.
    ///
    /// Returns an error if any of `o1`, `o2`, ... `o10` are errors.
    ///
    pub def lift10(f: (t1, t2, t3, t4, t5, t6, t7, t8, t9, t10) -> u & ef, 
                   o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5], 
                   o6: NamedRowEvaluator[t6], 
                   o7: NamedRowEvaluator[t7], 
                   o8: NamedRowEvaluator[t8], 
                   o9: NamedRowEvaluator[t9], 
                   o10: NamedRowEvaluator[t10]): NamedRowEvaluator[u] =
        ap(lift9(f, o1, o2, o3, o4, o5, o6, o7, o8, o9), o10)


    ///
    /// Returns a 2 element tuple with the results of applying the evaluators `o1` and `o2`.
    ///
    /// Returns an error if evaluating either `o1` or `o2` is an error.
    ///
    pub def tuple2(o1: NamedRowEvaluator[t1], o2: NamedRowEvaluator[t2]): NamedRowEvaluator[(t1, t2)] =
        lift2((x,y) -> (x,y), o1, o2)

    ///
    /// Returns a 3 element tuple with the results of applying the evaluators `o1`, `o2` and `o3`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2` and `o3` is an error.
    ///
    pub def tuple3(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3]): NamedRowEvaluator[(t1, t2, t3)] =
        lift3((x1, x2, x3) -> (x1, x2, x3), o1, o2, o3)

    ///
    /// Returns a 4 element tuple with the results of applying the evaluators `o1`, `o2`, `o3` and `o4`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, `o3` and `o4` is an error.
    ///
    pub def tuple4(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4]): NamedRowEvaluator[(t1, t2, t3, t4)]  =
        lift4((x1, x2, x3, x4) -> (x1, x2, x3, x4), o1, o2, o3, o4)

    ///
    /// Returns a 5 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o5`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o5` is an error.
    ///
    pub def tuple5(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5]): NamedRowEvaluator[(t1, t2, t3, t4, t5)]  =
        lift5((x1, x2, x3, x4, x5) -> (x1, x2, x3, x4, x5), o1, o2, o3, o4, o5)

    ///
    /// Returns a 6 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o6`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o6` is an error.
    ///
    pub def tuple6(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5], 
                   o6: NamedRowEvaluator[t6]): NamedRowEvaluator[(t1, t2, t3, t4, t5, t6)]  =
        lift6((x1, x2, x3, x4, x5, x6) -> (x1, x2, x3, x4, x5, x6), o1, o2, o3, o4, o5, o6)

    ///
    /// Returns a 7 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o7`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o7` is an error.
    ///
    pub def tuple7(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5], 
                   o6: NamedRowEvaluator[t6], 
                   o7: NamedRowEvaluator[t7]): NamedRowEvaluator[(t1, t2, t3, t4, t5, t6, t7)]  =
        lift7((x1, x2, x3, x4, x5, x6, x7) -> (x1, x2, x3, x4, x5, x6, x7), 
                o1, o2, o3, o4, o5, o6, o7)

    ///
    /// Returns a 8 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o8`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o8` is an error.
    ///
    pub def tuple8(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5], 
                   o6: NamedRowEvaluator[t6], 
                   o7: NamedRowEvaluator[t7], 
                   o8: NamedRowEvaluator[t8]): NamedRowEvaluator[(t1, t2, t3, t4, t5, t6, t7, t8)]  =
        lift8((x1, x2, x3, x4, x5, x6, x7, x8) -> (x1, x2, x3, x4, x5, x6, x7, x8), 
                o1, o2, o3, o4, o5, o6, o7, o8)

    ///
    /// Returns a 9 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o9`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o9` is an error.
    ///
    pub def tuple9(o1: NamedRowEvaluator[t1], 
                   o2: NamedRowEvaluator[t2], 
                   o3: NamedRowEvaluator[t3], 
                   o4: NamedRowEvaluator[t4], 
                   o5: NamedRowEvaluator[t5], 
                   o6: NamedRowEvaluator[t6], 
                   o7: NamedRowEvaluator[t7], 
                   o8: NamedRowEvaluator[t8], 
                   o9: NamedRowEvaluator[t9]): NamedRowEvaluator[(t1, t2, t3, t4, t5, t6, t7, t8, t9)]  =
        lift9((x1, x2, x3, x4, x5, x6, x7, x8, x9) -> (x1, x2, x3, x4, x5, x6, x7, x8, x9), 
                o1, o2, o3, o4, o5, o6, o7, o8, o9)

    ///
    /// Returns a 10 element tuple with the results of applying the evaluators `o1`, `o2`, ... `o10`.
    ///
    /// Returns an error if evaluating any of `o1`, `o2`, ... `o10` is an error.
    ///
    pub def tuple10(o1: NamedRowEvaluator[t1], 
                    o2: NamedRowEvaluator[t2], 
                    o3: NamedRowEvaluator[t3], 
                    o4: NamedRowEvaluator[t4], 
                    o5: NamedRowEvaluator[t5], 
                    o6: NamedRowEvaluator[t6], 
                    o7: NamedRowEvaluator[t7], 
                    o8: NamedRowEvaluator[t8], 
                    o9: NamedRowEvaluator[t9], 
                    o10: NamedRowEvaluator[t10]): NamedRowEvaluator[(t1, t2, t3, t4, t5, t6, t7, t8, t9, t10)]  =
        lift10((x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) -> (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10), 
                o1, o2, o3, o4, o5, o6, o7, o8, o9, o10)

    /// Alias for `seqRight`
    pub def *>(p1: NamedRowEvaluator[a], p2: NamedRowEvaluator[b]): NamedRowEvaluator[b] = seqRight(p1, p2)

    /// Alias for `seqLeft`
    pub def <*(p1: NamedRowEvaluator[a], p2: NamedRowEvaluator[b]): NamedRowEvaluator[a] = seqLeft(p1, p2)

    // Haskell's <$>
    pub def <&>(f: a -> b, p2: NamedRowEvaluator[a]): NamedRowEvaluator[b] =
        map(f, p2)

    pub def <&(x: b, p2: NamedRowEvaluator[a]): NamedRowEvaluator[b] =
        p2 *> return(x)

    /// Alias for `bind`
    pub def >>=(ma: NamedRowEvaluator[a], k: a -> NamedRowEvaluator[b]): NamedRowEvaluator[b] = 
        bind(ma, k)

    /// Alias for `flatMap` (flipped `bind`)
    pub def =<<(k: a -> NamedRowEvaluator[b], ma: NamedRowEvaluator[a]): NamedRowEvaluator[b] = 
        flatMap(k, ma)


    // Haskell's ap <*>
    pub def <*>(mf: NamedRowEvaluator[a -> b], p2: NamedRowEvaluator[a]): NamedRowEvaluator[b] =
        ap(mf, p2)

    /// Alias for `kleisliLeft`
    pub def >=>(f1: a -> NamedRowEvaluator[b], f2: b -> NamedRowEvaluator[c]): a -> NamedRowEvaluator[c] = 
        x -> kleisliLeft(f1, f2, x)

    /// Alias for `kleisliRight`
    pub def <=<(f1: b -> NamedRowEvaluator[c], f2: a -> NamedRowEvaluator[b]): a -> NamedRowEvaluator[c] = 
        x -> kleisliRight(f1, f2, x)


}

