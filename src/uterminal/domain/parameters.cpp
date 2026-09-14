#include "parameters.h"
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>

namespace ut {
namespace {
const QRegularExpression placeholders(QStringLiteral(R"(\$\{([^{}\r\n]+)\})"));
const QRegularExpression declarations(QStringLiteral(R"(^[\t ]*(?:Var|pVal)[\t ]+([^\s:=]+)[\t ]*(?::|=)[\t ]*\$\{([^{}\r\n]+)\}[\t ]*(?:\r?\n|$))"), QRegularExpression::MultilineOption);
QJsonObject definition(const QString &text, QString *error) {
    int colon = text.indexOf(':');
    int equals = text.indexOf('=');
    int sep = colon >= 0 && (equals < 0 || colon < equals) ? colon : equals;
    QString name = (sep < 0 ? text : text.left(sep)).trimmed();
    QString value = sep < 0 ? QString() : text.mid(sep + 1);
    QString kind = "text";
    if (name.contains('@')) {
        kind = name.section('@', 1);
        name = name.section('@', 0, 0);
        if (kind != "file") *error = QStringLiteral("不支持的参数类型：") + kind;
    }
    static const QRegularExpression valid(QStringLiteral(R"(^[\p{L}\p{N}_]+$)"));
    if (!valid.match(name).hasMatch()) *error = QStringLiteral("参数名无效：") + name;
    QJsonArray options;
    const QString optionSource = colon >= 0 && (equals < 0 || colon < equals) ? value : text;
    const auto parts = optionSource.split('|');
    if (parts.size() > 1) {
        bool choices = true;
        for (const auto &part : parts) choices &= part.contains('=');
        if (choices) {
            if (kind == "file") *error = QStringLiteral("文件参数不能同时包含下拉选项");
            kind = "choice";
            QSet<QString> labels;
            for (const auto &part : parts) {
                auto label = part.section('=', 0, 0).trimmed();
                auto actual = part.mid(part.indexOf('=') + 1).trimmed();
                if (label.isEmpty() || actual.isEmpty() || labels.contains(label))
                    *error = QStringLiteral("下拉选项为空或重复");
                labels.insert(label);
                options.append(QJsonObject{{"label", label}, {"value", actual}});
            }
            value = options.first().toObject()["value"].toString();
        }
    }
    return {{"id", name}, {"label", name}, {"kind", kind}, {"default", value},
            {"required", true}, {"options", options}};
}
}

ParameterResult Parameters::parse(const QString &source, const QJsonArray &metadata) {
    ParameterResult result;
    QHash<QString,int> positions;
    QSet<QString> defined;
    QSet<QString> declared;
    auto add=[&](const QJsonObject &parameter,bool explicitDefinition){
        const auto id=parameter["id"].toString();
        if(!positions.contains(id)){
            positions[id]=result.parameters.size();result.parameters.append(parameter);
            if(explicitDefinition)defined.insert(id);return;
        }
        if(!explicitDefinition)return;
        const auto index=positions.value(id);
        if(defined.contains(id)){
            auto previous=result.parameters[index].toObject();auto next=parameter;
            previous.remove("label");next.remove("label");
            if(previous!=next)result.error=QStringLiteral("参数定义冲突：")+id;
        }else{result.parameters[index]=parameter;defined.insert(id);}
    };
    auto decls = declarations.globalMatch(source);
    while (decls.hasNext()) {
        auto match = decls.next();
        auto parameter = definition(match.captured(2), &result.error);
        auto alias = definition(match.captured(1), &result.error)["id"].toString();
        parameter["id"] = alias;
        declared.insert(alias);
        add(parameter,true);
    }
    QString body = source;
    body.remove(declarations);
    auto matches = placeholders.globalMatch(body);
    while (matches.hasNext()) {
        const auto text=matches.next().captured(1);
        auto parameter = definition(text, &result.error);
        add(parameter,text.contains(':')||text.contains('=')||text.contains('@'));
    }
    QSet<QString> metadataIds;
    for(const auto &entry:metadata){
        const auto data=entry.toObject();const auto id=data.value("id").toString();
        QString problem;const auto checked=definition(id,&problem);
        if(!entry.isObject() || !problem.isEmpty() || checked.value("id").toString()!=id || metadataIds.contains(id)){
            result.error=QStringLiteral("参数元数据 ID 无效或重复：")+id;return result;
        }
        metadataIds.insert(id);
        const auto kind=data.value("kind").toString("text");
        if(!QStringList{"text","file","choice","integer","number","directory","multiline","boolean","secret"}.contains(kind)){
            result.error=QStringLiteral("尚不支持迁移此参数类型：")+id+" ("+kind+")";return result;
        }
        if((data.contains("label")&&!data.value("label").isString()) ||
           (data.contains("placeholder")&&!data.value("placeholder").isString()) ||
           (data.contains("required")&&!data.value("required").isBool())){
            result.error=QStringLiteral("参数元数据格式无效：")+id;return result;
        }
        // Match the legacy custom-script synchronizer: templates own defaults,
        // choice/file types and options; declarations additionally own labels.
        if(!positions.contains(id))continue;
        const auto position=positions.value(id);auto parameter=result.parameters[position].toObject();
        // Legacy numeric fields were text inputs and used verbatim template
        // substitution. Preserve their type without rounding/coercing values.
        if(parameter.value("kind").toString()=="text" && QStringList{"integer","number","directory","multiline","boolean","secret"}.contains(kind))parameter["kind"]=kind;
        if(parameter.value("kind").toString()=="boolean")parameter["default"]=!parameter.value("default").toString().isEmpty();
        if(data.contains("label")&&!declared.contains(id))parameter["label"]=data.value("label");
        if(data.contains("required"))parameter["required"]=data.value("required");
        if(data.contains("placeholder"))parameter["placeholder"]=data.value("placeholder");
        result.parameters[position]=parameter;
    }
    return result;
}

QString Parameters::render(const QString &source, const QVariantMap &values, QString *error, const QJsonArray &metadata) {
    auto parsed = parse(source,metadata);
    *error = parsed.error;
    if (!error->isEmpty()) return {};
    QVariantMap resolved;
    for (const auto &entry : parsed.parameters) {
        auto p = entry.toObject();
        auto id = p["id"].toString();
        const auto input=values.value(id,p["default"].toVariant());
        auto value = input.toString();
        if(p["kind"].toString()=="boolean"){
            if(input.metaType().id()!=QMetaType::Bool){*error=QStringLiteral("布尔参数必须是勾选状态：")+p["label"].toString();return {};}
            value=input.toBool()?"True":"False";
        }
        if (value.isEmpty() && p["required"].toBool()) {
            *error = QStringLiteral("请填写参数：") + p["label"].toString(); return {};
        }
        if(p["kind"].toString()=="choice"){
            bool valid=false;
            for(const auto &option:p["options"].toArray())valid|=option.toObject()["value"].toString()==value;
            if(!valid){*error=QStringLiteral("请选择有效选项：")+p["label"].toString();return {};}
        }
        resolved[id] = value;
    }
    QString body = source;
    body.remove(declarations);
    QString rendered;
    qsizetype position = 0;
    auto matches = placeholders.globalMatch(body);
    while (matches.hasNext()) {
        auto match = matches.next();
        auto p = definition(match.captured(1), error);
        rendered += body.mid(position, match.capturedStart() - position);
        rendered += resolved.value(p["id"].toString()).toString();
        position = match.capturedEnd();
    }
    return rendered + body.mid(position);
}

QString Parameters::withDefault(const QString &source, const QString &id, const QString &value) {
    QString result = source;
    auto updatedDefinition=[&value](const QJsonObject &p){
        QString name=p["id"].toString();
        if(p["kind"].toString()=="choice"){
            QStringList options;QString chosen;
            for(const auto &entry:p["options"].toArray()){
                const auto option=entry.toObject();const auto text=option["label"].toString()+"="+option["value"].toString();
                if(chosen.isEmpty()&&option["value"].toString()==value)chosen=text;else options.append(text);
            }
            if(chosen.isEmpty())return QString();
            options.prepend(chosen);return name+":"+options.join('|');
        }
        if(p["kind"].toString()=="file")name+="@file";
        return name+":"+value;
    };
    // A declaration owns its alias's default; references must remain references.
    auto decls = declarations.globalMatch(source);
    QList<QRegularExpressionMatch> owned;
    QList<QRegularExpressionMatch> allDeclarations;
    while (decls.hasNext()) {
        auto match = decls.next();
        allDeclarations.append(match);
        if (match.captured(1) == id) owned.append(match);
    }
    if (!owned.isEmpty()) {
        for (auto it = owned.crbegin(); it != owned.crend(); ++it) {
            QString error;
            auto p = definition(it->captured(2), &error);
            if (!error.isEmpty()) continue;
            const auto replacement=updatedDefinition(p);
            if(!replacement.isEmpty())result.replace(it->capturedStart(2), it->capturedLength(2), replacement);
        }
        return result;
    }
    auto matches = placeholders.globalMatch(source);
    QList<QRegularExpressionMatch> found;
    while (matches.hasNext()) found.append(matches.next());
    for (auto it = found.crbegin(); it != found.crend(); ++it) {
        bool inDeclaration = false;
        for (const auto &decl : allDeclarations)
            inDeclaration |= it->capturedStart() >= decl.capturedStart() && it->capturedStart() < decl.capturedEnd();
        if (inDeclaration) continue;
        QString error;
        auto p = definition(it->captured(1), &error);
        if (error.isEmpty() && p["id"].toString() == id) {
            const auto replacement=updatedDefinition(p);
            if(!replacement.isEmpty())result.replace(it->capturedStart(), it->capturedLength(), "${" + replacement + "}");
        }
    }
    return result;
}
}
