package com.doorworkflow.service;

import com.doorworkflow.entity.Job;
import com.doorworkflow.entity.JobStep;
import com.doorworkflow.entity.ProcessStep;
import com.doorworkflow.enums.JobStepStatus;
import com.doorworkflow.repository.JobRepository;
import com.doorworkflow.repository.JobStepRepository;
import com.doorworkflow.repository.ProcessStepRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class LogExportService {

    private static final String SHEET_NAME = "Job Logs";

    private static final String[] FIXED_HEADERS = {
            "FR",
            "CUSTOMER NAME",
            "DELIVERY ADDRESS",
            "PO NO.",
            "GST No.",
            "PO DATE",
            "ORDER DATE",
            "DELIVERY DATE",
            "DOOR'S",
            "DOOR LEAF",
            "COLOUR SHADE"
    };

    private static final String[] FINAL_FIXED_HEADERS = {
            "CHALLAN NO.",
            "VEHICLE DETAILS"
    };

    private static final DateTimeFormatter DATE_FORMATTER =
            DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final JobRepository jobRepository;
    private final JobStepRepository jobStepRepository;
    private final ProcessStepRepository processStepRepository;

    public LogExportService(JobRepository jobRepository,
                            JobStepRepository jobStepRepository,
                            ProcessStepRepository processStepRepository) {
        this.jobRepository = jobRepository;
        this.jobStepRepository = jobStepRepository;
        this.processStepRepository = processStepRepository;
    }

    @Transactional(readOnly = true)
    public byte[] generateJobLogsExcel() {
        List<Job> jobs = jobRepository.findAllByOrderByCreatedAtDesc();
        List<JobStep> allSteps = jobStepRepository.findAll();
        List<ProcessStep> activeProcessSteps = processStepRepository.findByIsActiveTrueOrderByStepOrderAsc();

        Map<UUID, List<JobStep>> stepsByJobId = allSteps.stream()
                .filter(step -> step.getJob() != null)
                .collect(Collectors.groupingBy(step -> step.getJob().getId()));

        try (Workbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {

            Sheet sheet = workbook.createSheet(SHEET_NAME);
            sheet.createFreezePane(0, 1);

            CellStyle headerStyle = workbook.createCellStyle();
            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            CellStyle textStyle = workbook.createCellStyle();
            DataFormat dataFormat = workbook.createDataFormat();
            textStyle.setDataFormat(dataFormat.getFormat("@"));

            // Build dynamic headers: Fixed + ProcessSteps + Final Fixed
            List<String> headersList = new ArrayList<>();
            for (String h : FIXED_HEADERS) {
                headersList.add(h);
            }
            for (ProcessStep ps : activeProcessSteps) {
                headersList.add(ps.getName());
            }
            for (String h : FINAL_FIXED_HEADERS) {
                headersList.add(h);
            }

            Row headerRow = sheet.createRow(0);
            for (int col = 0; col < headersList.size(); col++) {
                Cell cell = headerRow.createCell(col);
                cell.setCellValue(headersList.get(col));
                cell.setCellStyle(headerStyle);
            }

            int rowIdx = 1;
            for (Job job : jobs) {
                Row row = sheet.createRow(rowIdx++);
                List<JobStep> jobSteps = stepsByJobId.getOrDefault(job.getId(), List.of());

                int colIdx = 0;

                // Fixed job columns
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getFr()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getCompanyName()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getDeliveryAddress()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getPoNo()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getGstNo()));
                row.createCell(colIdx++).setCellValue(job.getPoDate() != null ? job.getPoDate().format(DATE_FORMATTER) : "");
                row.createCell(colIdx++).setCellValue(job.getOrderDate() != null ? job.getOrderDate().format(DATE_FORMATTER) : "");
                row.createCell(colIdx++).setCellValue(job.getDeliveryDate() != null ? job.getDeliveryDate().format(DATE_FORMATTER) : "");
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getDoors()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getDoorLeaf()));
                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getColourShade()));

                // Dynamic process-step columns
                for (ProcessStep ps : activeProcessSteps) {
                    row.createCell(colIdx++).setCellValue(getStageValue(jobSteps, ps.getName()));
                }

                // Final fixed columns
                Cell chalanCell = row.createCell(colIdx++);
                chalanCell.setCellValue(nullToEmpty(job.getChalanNumber()));
                chalanCell.setCellStyle(textStyle);

                row.createCell(colIdx++).setCellValue(nullToEmpty(job.getVehicleDetails()));
            }

            for (int col = 0; col < headersList.size(); col++) {
                sheet.autoSizeColumn(col);
            }

            workbook.write(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Failed to generate Excel export", e);
        }
    }

    private String getStageValue(List<JobStep> steps, String stageName) {
        for (JobStep step : steps) {
            if (step.getStepName() != null && step.getStepName().equalsIgnoreCase(stageName)) {
                if (step.getStatus() == JobStepStatus.COMPLETED && step.getCompletedAt() != null) {
                    String dateStr = DATE_FORMATTER.format(
                            step.getCompletedAt().atZone(ZoneId.of("Asia/Kolkata")));
                    String person = (step.getCompletedBy() != null && step.getCompletedBy().getName() != null)
                            ? step.getCompletedBy().getName()
                            : "Unknown";
                    return dateStr + " - " + person;
                }
                return "Pending";
            }
        }
        // No JobStep record exists for this process step (e.g., step added after job creation)
        return "Pending";
    }

    private static String nullToEmpty(String value) {
        return value != null ? value : "";
    }
}
